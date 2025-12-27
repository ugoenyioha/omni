FROM nginx:alpine

# Add stream configuration for UDP proxy
COPY nginx/stream-udp.conf /etc/nginx/stream-udp.conf
RUN echo "include /etc/nginx/stream-udp.conf;" >> /etc/nginx/nginx.conf

# Add the wait-for-certs script
COPY nginx/wait-for-certs.sh /wait-for-certs.sh
RUN chmod +x /wait-for-certs.sh

# Use the wait script as the entrypoint
ENTRYPOINT ["/wait-for-certs.sh"]