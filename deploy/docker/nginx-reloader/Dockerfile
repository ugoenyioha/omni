FROM alpine:3.19

# Install inotify-tools and procps for kill command
RUN apk add --no-cache \
    inotify-tools \
    bash \
    procps

# Copy the reload watcher script
COPY nginx-reloader/reload-watcher.sh /reload-watcher.sh
RUN chmod +x /reload-watcher.sh

# Run the reload watcher
CMD ["/reload-watcher.sh"]