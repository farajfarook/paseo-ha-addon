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
ENV ONNXRUNTIME_NODE_INSTALL=skip \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    npm_config_audit=false
RUN apk add --no-cache nodejs npm git bash curl build-base python3 linux-headers
RUN npm install -g --prefix /opt/node "@getpaseo/cli@${PASEO_VERSION}" \
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

# Static GitHub CLI (`gh`) from cli/cli releases, verified against the release
# checksums. Agents use it for GitHub and as git's HTTPS credential helper.
ARG GH_CLI_VERSION=2.102.0
RUN set -eu; \
    case "${BUILD_ARCH:-${TARGETARCH:-$(uname -m)}}" in \
      amd64|x86_64) arch=amd64 ;; \
      aarch64|arm64) arch=arm64 ;; \
      *) echo "unsupported architecture for gh" >&2; exit 1 ;; \
    esac; \
    v="$GH_CLI_VERSION"; base="https://github.com/cli/cli/releases/download/v${v}"; \
    tgz="gh_${v}_linux_${arch}.tar.gz"; \
    cd /tmp; \
    curl -fsSLO "${base}/${tgz}"; \
    curl -fsSL "${base}/gh_${v}_checksums.txt" | grep " ${tgz}\$" | sha256sum -c -; \
    tar -xzf "${tgz}"; \
    install -m 755 "gh_${v}_linux_${arch}/bin/gh" /usr/local/bin/gh; \
    rm -rf /tmp/gh_*; \
    /usr/local/bin/gh --version

# ---------------------------------------------------------------------------
# Runtime image
# ---------------------------------------------------------------------------
FROM ${BUILD_FROM}
ARG PASEO_VERSION=0.10.3
ENV ONNXRUNTIME_NODE_INSTALL=skip \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    npm_config_audit=false \
    PATH=/opt/node/bin:$PATH \
    PASEO_HA_PASEO_VERSION=${PASEO_VERSION}

RUN apk add --no-cache nodejs npm nginx git openssh-client bash curl jq libstdc++ coreutils \
 && rm -f /etc/nginx/http.d/default.conf

COPY --from=build /opt/node /opt/node
COPY --from=build /usr/local/bin/ha /usr/local/bin/ha
COPY --from=build /usr/local/bin/gh /usr/local/bin/gh
COPY rootfs /

RUN chmod +x /usr/local/bin/paseo-ha-* /etc/s6-overlay/scripts/*.sh \
      /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish \
 && node --version && paseo --version && ha help >/dev/null && gh --version

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD curl -fsS -o /dev/null --max-time 8 http://127.0.0.1:6767/api/health || exit 1

LABEL io.hass.type="addon" \
      io.hass.paseo.version="${PASEO_VERSION}"
