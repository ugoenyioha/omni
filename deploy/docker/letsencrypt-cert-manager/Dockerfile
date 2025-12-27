FROM alpine:3.18

# Install certbot with cloudflare plugin and dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    bash \
    curl \
    jq \
    openssl

# Install certbot and cloudflare plugin
RUN pip3 install --no-cache-dir \
    certbot \
    certbot-dns-cloudflare

# Create directories
RUN mkdir -p /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt /etc/nginx/ssl

# Copy the certificate manager script
COPY ./letsencrypt-cert-manager.sh /usr/local/bin/letsencrypt-cert-manager.sh
RUN chmod +x /usr/local/bin/letsencrypt-cert-manager.sh

# Run the certificate manager
CMD ["/usr/local/bin/letsencrypt-cert-manager.sh"]