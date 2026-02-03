FROM ghcr.io/cybedefend/cybedefend-cli:v1.0.10

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
