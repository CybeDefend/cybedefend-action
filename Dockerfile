FROM ghcr.io/cybedefend/cybedefend-cli:v2.0.0

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
