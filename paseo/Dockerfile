# syntax=docker/dockerfile:1
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest

# ---------------------------------------------------------------------------
# Build stage: compile native Node modules (node-pty) against musl
# ---------------------------------------------------------------------------
FROM ${BUILD_FROM} AS build
ARG PASEO_VERSION=0.10.3
ARG PI_VERSION=1.0.0
ENV ONNXRUNTIME_NODE_INSTALL=skip \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    npm_config_audit=false
RUN apk add --no-cache nodejs npm git bash build-base python3 linux-headers
RUN npm install -g --prefix /opt/node "@getpaseo/cli@${PASEO_VERSION}" \
 && npm install -g --prefix /opt/node --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}" \
 && npm cache clean --force

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
COPY rootfs /

RUN chmod +x /usr/local/bin/paseo-ha-* /etc/s6-overlay/scripts/*.sh \
      /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish \
 && node --version && paseo --version && pi --version

LABEL io.hass.type="addon" \
      io.hass.paseo.version="${PASEO_VERSION}" \
      io.hass.pi.version="${PI_VERSION}"
