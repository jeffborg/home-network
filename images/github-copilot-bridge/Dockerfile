FROM debian:trixie-20260421

ARG COPILOT_VERSION=v1.0.37
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates curl socat tar \
    && update-ca-certificates \
    && case "$TARGETARCH" in \
        amd64) ARCH="x64" ;; \
        arm64) ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac \
    && ASSET="copilot-linux-$ARCH.tar.gz" \
    && BASE_URL="https://github.com/github/copilot-cli/releases/download/$COPILOT_VERSION" \
    && curl -fsSL "$BASE_URL/SHA256SUMS.txt" -o /tmp/SHA256SUMS.txt \
    && curl -fsSL "$BASE_URL/$ASSET" -o "/tmp/$ASSET" \
    && cd /tmp \
    && grep " $ASSET$" SHA256SUMS.txt | sha256sum -c - \
    && tar -xzf "$ASSET" \
    && install -m 0755 copilot /usr/local/bin/copilot \
    && rm -rf /tmp/SHA256SUMS.txt "/tmp/$ASSET"

ENV SSL_CERT_DIR=/etc/ssl/certs \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    COPILOT_PORT=8001 \
    COPILOT_PROXY_PORT=8000

COPY entrypoint.sh /usr/local/bin/github-copilot-bridge

RUN chmod +x /usr/local/bin/github-copilot-bridge

EXPOSE 8000

ENTRYPOINT ["/usr/local/bin/github-copilot-bridge"]
