FROM alpine:3.19

RUN apk add --no-cache \
    bind-tools \
    bash \
    curl \
    jq \
    iproute2

# Copy the update script
COPY ddns-updater/ddns-updater.sh /usr/local/bin/ddns-updater.sh
RUN chmod +x /usr/local/bin/ddns-updater.sh

# Run as non-root user
RUN adduser -D -s /bin/bash ddns
USER ddns

CMD ["/usr/local/bin/ddns-updater.sh"]