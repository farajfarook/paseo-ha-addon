# syntax=docker/dockerfile:1
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest

# ---------------------------------------------------------------------------
# Build stage: compile native Node modules (node-pty) against musl.
# node-pty's bundled prebuilds are glibc-linked (linux-arm64 needs
# ld-linux-aarch64.so.1, and there is none for linux-arm), so it is always
# rebuilt from source here (without prebuilds/ its install script runs
# node-gyp).
# ---------------------------------------------------------------------------
FROM ${BUILD_FROM} AS build
ARG PASEO_VERSION=0.10.3
ARG PI_VERSION=1.0.0
ENV ONNXRUNTIME_NODE_INSTALL=skip \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    npm_config_audit=false
RUN apk add --no-cache nodejs npm git bash curl build-base python3 linux-headers
RUN npm install -g --prefix /opt/node "@getpaseo/cli@${PASEO_VERSION}" \
 && npm install -g --prefix /opt/node --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}" \
 && cd /opt/node/lib/node_modules/@getpaseo/cli \
 && rm -rf node_modules/node-pty/prebuilds \
 && npm rebuild node-pty \
 && npm cache clean --force \
 && node -e "require('node-pty')"

# Static `ha` CLI from home-assistant/cli releases. The HA builder passes
# BUILD_ARCH (aarch64|amd64); plain buildx provides TARGETARCH.
ARG BUILD_ARCH
ARG TARGETARCH
ARG HA_CLI_VERSION=5.5.0
RUN set -eu; \
    arch="${BUILD_ARCH:-}"; \
    if [ -z "$arch" ]; then \
      case "${TARGETARCH:-$(uname -m)}" in \
        amd64|x86_64) arch=amd64 ;; \
        arm64|aarch64) arch=aarch64 ;; \
        *) echo "unsupported architecture: ${TARGETARCH:-$(uname -m)}" >&2; exit 1 ;; \
      esac; \
    fi; \
    version="$HA_CLI_VERSION"; \
    curl -fsSL -o /usr/local/bin/ha \
      "https://github.com/home-assistant/cli/releases/download/${version}/ha_${arch}"; \
    chmod 755 /usr/local/bin/ha; \
    /usr/local/bin/ha help >/dev/null

# ---------------------------------------------------------------------------
# Runtime image
# ---------------------------------------------------------------------------
FROM ${BUILD_FROM}
ARG PASEO_VERSION=0.10.3
ARG PI_VERSION=1.0.0
ENV ONNXRUNTIME_NODE_INSTALL=skip \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    npm_config_audit=false \
    PATH=/opt/node/bin:$PATH \
    PASEO_HA_PASEO_VERSION=${PASEO_VERSION} \
    PASEO_HA_PI_VERSION=${PI_VERSION}

RUN apk add --no-cache nodejs npm nginx git openssh-client bash curl jq libstdc++ coreutils \
 && rm -f /etc/nginx/http.d/default.conf

COPY --from=build /opt/node /opt/node
COPY --from=build /usr/local/bin/ha /usr/local/bin/ha
COPY rootfs /

RUN chmod +x /usr/local/bin/paseo-ha-* /etc/s6-overlay/scripts/*.sh \
      /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish \
 && node --version && paseo --version && pi --version && ha help >/dev/null

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD curl -fsS -o /dev/null --max-time 8 http://127.0.0.1:6767/api/health || exit 1

LABEL io.hass.type="addon" \
      io.hass.paseo.version="${PASEO_VERSION}" \
      io.hass.pi.version="${PI_VERSION}"
