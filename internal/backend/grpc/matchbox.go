// Copyright (c) 2025 Sidero Labs, Inc.
//
// Use of this software is governed by the Business Source License
// included in the LICENSE file.

package grpc

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"go.uber.org/zap"
	"google.golang.org/grpc"

	"github.com/siderolabs/omni/client/api/omni/management"
	"github.com/siderolabs/omni/internal/pkg/auth"
	"github.com/siderolabs/omni/internal/pkg/auth/role"
	"github.com/siderolabs/omni/internal/pkg/config"
)

// PushToMatchbox implements ManagementServer.
func (s *managementServer) PushToMatchbox(request *management.PushToMatchboxRequest, srv grpc.ServerStreamingServer[management.PushToMatchboxResponse]) error {
	ctx := srv.Context()

	// Check if push-to-matchbox is enabled
	if !config.Config.Matchbox.Enabled {
		return fmt.Errorf("push-to-matchbox feature is disabled")
	}

	// Check permissions
	if _, err := auth.CheckGRPC(ctx, auth.WithRole(role.Operator)); err != nil {
		return err
	}

	// Send initial progress
	if err := srv.Send(&management.PushToMatchboxResponse{
		Progress: &management.PushToMatchboxResponse_Progress{
			Message:    "Creating schematic...",
			Percentage: 10,
		},
	}); err != nil {
		return err
	}

	// Create schematic using existing logic
	schematicReq := &management.CreateSchematicRequest{
		Extensions:               request.Extensions,
		ExtraKernelArgs:          request.ExtraKernelArgs,
		MetaValues:               request.MetaValues,
		TalosVersion:             request.TalosVersion,
		MediaId:                  request.MediaId,
		SecureBoot:               request.SecureBoot,
		SiderolinkGrpcTunnelMode: request.SiderolinkGrpcTunnelMode,
		JoinToken:                request.JoinToken,
	}

	schematicResp, err := s.CreateSchematic(ctx, schematicReq)
	if err != nil {
		return fmt.Errorf("failed to create schematic: %w", err)
	}

	// Send progress update
	if err := srv.Send(&management.PushToMatchboxResponse{
		Progress: &management.PushToMatchboxResponse_Progress{
			Message:    "Downloading kernel and initramfs...",
			Percentage: 20,
		},
	}); err != nil {
		return err
	}

	// Get kernel arguments from the schematic
	baseKernelArgs, _, err := s.getBaseKernelArgs(ctx, request.SiderolinkGrpcTunnelMode, request.JoinToken)
	if err != nil {
		return fmt.Errorf("failed to get base kernel args: %w", err)
	}

	// Combine all kernel arguments
	allKernelArgs := append(baseKernelArgs, request.ExtraKernelArgs...)

	// Send progress update
	if err := srv.Send(&management.PushToMatchboxResponse{
		Progress: &management.PushToMatchboxResponse_Progress{
			Message:    "Downloading kernel...",
			Percentage: 30,
		},
	}); err != nil {
		return err
	}

	// Download kernel and initramfs directly from image factory
	baseURL := config.Config.Registries.ImageFactoryBaseURL
	if baseURL == "" {
		baseURL = "https://factory.talos.dev"
	}

	// Create assets directory if it doesn't exist
	matchboxAssetsPath := config.Config.Matchbox.AssetsPath
	if matchboxAssetsPath == "" {
		matchboxAssetsPath = "/var/lib/matchbox/assets/talos"
	}

	if err := os.MkdirAll(matchboxAssetsPath, 0755); err != nil {
		return fmt.Errorf("failed to create matchbox assets directory: %w", err)
	}

	// Download kernel
	kernelURL := fmt.Sprintf("%s/image/%s/v%s/kernel-amd64", baseURL, schematicResp.SchematicId, request.TalosVersion)
	kernelPath := filepath.Join(matchboxAssetsPath, fmt.Sprintf("kernel-%s", schematicResp.SchematicId))

	if err := downloadFile(kernelURL, kernelPath, srv, 30, 50); err != nil {
		return fmt.Errorf("failed to download kernel: %w", err)
	}

	// Make kernel executable
	if err := os.Chmod(kernelPath, 0755); err != nil {
		return fmt.Errorf("failed to chmod kernel: %w", err)
	}

	s.logger.Info("downloaded kernel", zap.String("path", kernelPath))

	// Send progress update
	if err := srv.Send(&management.PushToMatchboxResponse{
		Progress: &management.PushToMatchboxResponse_Progress{
			Message:    "Downloading initramfs...",
			Percentage: 50,
		},
	}); err != nil {
		return err
	}

	// Download initramfs
	initramfsURL := fmt.Sprintf("%s/image/%s/v%s/initramfs-amd64.xz", baseURL, schematicResp.SchematicId, request.TalosVersion)
	initramfsPath := filepath.Join(matchboxAssetsPath, fmt.Sprintf("initramfs-%s.xz", schematicResp.SchematicId))

	if err := downloadFile(initramfsURL, initramfsPath, srv, 50, 90); err != nil {
		return fmt.Errorf("failed to download initramfs: %w", err)
	}

	s.logger.Info("downloaded initramfs", zap.String("path", initramfsPath))

	// Send progress update
	if err := srv.Send(&management.PushToMatchboxResponse{
		Progress: &management.PushToMatchboxResponse_Progress{
			Message:    "Creating Matchbox profile...",
			Percentage: 90,
		},
	}); err != nil {
		return err
	}

	// Create Matchbox profiles
	profilePath := config.Config.Matchbox.ProfilesPath
	if profilePath == "" {
		profilePath = "/var/lib/matchbox/profiles"
	}

	if err := os.MkdirAll(profilePath, 0755); err != nil {
		return fmt.Errorf("failed to create matchbox profiles directory: %w", err)
	}

	// Build kernel args
	initrdFilename := fmt.Sprintf("initramfs-%s.xz", schematicResp.SchematicId)

	// Create both controlplane and worker profiles
	roles := []string{"controlplane", "worker"}

	for _, roleType := range roles {
		profileName := fmt.Sprintf("talos-%s-%s", roleType, schematicResp.SchematicId[:8])
		profileFile := filepath.Join(profilePath, profileName+".json")

		// Start with initrd reference as first argument (required for PXE boot)
		kernelArgs := []string{
			fmt.Sprintf("initrd=%s", initrdFilename),
		}

		// Add common kernel arguments
		commonArgs := []string{
			"init_on_alloc=1",
			"slab_nomerge",
			"pti=on",
			"console=tty0",
			"printk.devkmsg=on",
			"talos.platform=metal",
		}
		kernelArgs = append(kernelArgs, commonArgs...)

		// Add all the Omni-specific kernel arguments
		kernelArgs = append(kernelArgs, allKernelArgs...)

		profile := map[string]interface{}{
			"id":   profileName,
			"name": fmt.Sprintf("Talos %s %s (schematic %s)", strings.Title(roleType), request.TalosVersion, schematicResp.SchematicId[:8]), //nolint:staticcheck
			"boot": map[string]interface{}{
				"kernel": fmt.Sprintf("/assets/talos/kernel-%s", schematicResp.SchematicId),
				"initrd": []string{fmt.Sprintf("/assets/talos/%s", initrdFilename)},
				"args":   kernelArgs,
			},
		}

		profileJSON, err := json.MarshalIndent(profile, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal profile: %w", err)
		}

		if err := os.WriteFile(profileFile, profileJSON, 0644); err != nil {
			return fmt.Errorf("failed to write profile file: %w", err)
		}

		s.logger.Info("created matchbox profile",
			zap.String("role", roleType),
			zap.String("profile", profileName),
			zap.String("path", profileFile))
	}

	// Optionally update existing groups to use new profiles
	groupsPath := config.Config.Matchbox.GroupsPath
	if groupsPath == "" {
		groupsPath = "/var/lib/matchbox/groups"
	}

	updateGroups := config.Config.Matchbox.UpdateGroups

	if updateGroups {
		if err := updateMatchboxGroups(s.logger, groupsPath, schematicResp.SchematicId); err != nil {
			s.logger.Warn("failed to update matchbox groups", zap.Error(err))
		}
	}

	// Send completion
	if err := srv.Send(&management.PushToMatchboxResponse{
		Progress: &management.PushToMatchboxResponse_Progress{
			Message:    "Successfully pushed to Matchbox",
			Percentage: 100,
			Complete:   true,
		},
	}); err != nil {
		return err
	}

	s.logger.Info("pushed to matchbox",
		zap.String("schematic_id", schematicResp.SchematicId),
		zap.Strings("kernel_args", allKernelArgs))

	return nil
}

// downloadFile downloads a file from URL and saves it to destPath with progress updates.
func downloadFile(url, destPath string, srv grpc.ServerStreamingServer[management.PushToMatchboxResponse], startProgress, endProgress int32) error {
	resp, err := http.Get(url) //nolint:gosec
	if err != nil {
		return fmt.Errorf("failed to download from %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)

		return fmt.Errorf("download failed with status %d: %s", resp.StatusCode, string(body))
	}

	file, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("failed to create file %s: %w", destPath, err)
	}
	defer file.Close()

	// Download with progress tracking
	var downloaded int64

	contentLength := resp.ContentLength
	buf := make([]byte, 1024*1024) // 1MB buffer

	for {
		n, err := resp.Body.Read(buf)
		if n > 0 {
			if _, writeErr := file.Write(buf[:n]); writeErr != nil {
				return fmt.Errorf("failed to write to file: %w", writeErr)
			}

			downloaded += int64(n)

			// Update progress
			if contentLength > 0 {
				progressRange := endProgress - startProgress
				progress := startProgress + int32((downloaded * int64(progressRange) / contentLength))

				srv.Send(&management.PushToMatchboxResponse{ //nolint:errcheck
					Progress: &management.PushToMatchboxResponse_Progress{
						Message:    fmt.Sprintf("Downloading... %d MB / %d MB", downloaded/(1024*1024), contentLength/(1024*1024)),
						Percentage: progress,
					},
				})
			}
		}

		if err == io.EOF {
			break
		}

		if err != nil {
			return fmt.Errorf("download error: %w", err)
		}
	}

	return nil
}

// updateMatchboxGroups updates existing matchbox group files to use new profiles.
func updateMatchboxGroups(logger *zap.Logger, groupsPath, schematicID string) error {
	entries, err := os.ReadDir(groupsPath)
	if err != nil {
		return fmt.Errorf("failed to read groups directory: %w", err)
	}

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}

		groupFile := filepath.Join(groupsPath, entry.Name())

		// Read existing group
		data, err := os.ReadFile(groupFile)
		if err != nil {
			logger.Warn("failed to read group file",
				zap.String("file", entry.Name()),
				zap.Error(err))

			continue
		}

		var group map[string]interface{}
		if err := json.Unmarshal(data, &group); err != nil {
			logger.Warn("failed to unmarshal group",
				zap.String("file", entry.Name()),
				zap.Error(err))

			continue
		}

		// Determine role from group name
		roleType := "worker"
		if strings.Contains(strings.ToLower(entry.Name()), "controlplane") ||
			strings.Contains(strings.ToLower(entry.Name()), "control-plane") {
			roleType = "controlplane"
		}

		// Update profile reference
		newProfileName := fmt.Sprintf("talos-%s-%s", roleType, schematicID[:8])
		group["profile"] = newProfileName

		// Write updated group
		updatedJSON, err := json.MarshalIndent(group, "", "  ")
		if err != nil {
			logger.Warn("failed to marshal updated group",
				zap.String("file", entry.Name()),
				zap.Error(err))

			continue
		}

		if err := os.WriteFile(groupFile, updatedJSON, 0644); err != nil {
			logger.Warn("failed to write updated group",
				zap.String("file", entry.Name()),
				zap.Error(err))

			continue
		}

		logger.Info("updated matchbox group",
			zap.String("group", entry.Name()),
			zap.String("profile", newProfileName))
	}

	return nil
}
