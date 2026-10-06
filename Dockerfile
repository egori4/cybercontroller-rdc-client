FROM node:22.23.3-bookworm-slim

ARG DESKTOP_COMMANDER_VERSION=0.2.52

ENV NODE_ENV=production \
    HOME=/home/rdc \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    PUPPETEER_SKIP_DOWNLOAD=true \
    MCP_BEARER_TOKEN_FILE=/run/rdc-client/token \
    MCP_CA_CERT_FILE=/run/rdc-client/ca.crt

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates jq \
 && npm install -g "@wonderwhy-er/desktop-commander@${DESKTOP_COMMANDER_VERSION}" \
 && npm cache clean --force \
 && rm -rf /var/lib/apt/lists/*

# Desktop Commander 0.2.52 preemptively downloads Chrome for its PDF writer.
# This hardened client intentionally does not provide PDF-generation capability.
# A harmless placeholder satisfies its "system Chrome exists" startup check and
# prevents a large runtime browser download into ephemeral storage.
RUN printf '%s\n' '#!/bin/sh' 'echo "Chromium is intentionally disabled in rdc-client" >&2' 'exit 126' > /usr/bin/chromium \
 && chmod 0755 /usr/bin/chromium

WORKDIR /opt/rdc-client
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY src/mcpctl-launcher.sh /usr/local/bin/mcpctl

RUN chmod 0755 /usr/local/bin/mcpctl /usr/local/bin/docker-entrypoint.sh \
 && useradd --uid 10001 --user-group --create-home --home-dir /home/rdc --shell /bin/sh rdc \
 && mkdir -p /home/rdc/.desktop-commander-device /home/rdc/.claude-server-commander /home/rdc/.npm /run/rdc-client \
 && chown -R 10001:10001 /home/rdc /run/rdc-client

USER 10001:10001
WORKDIR /home/rdc

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["desktop-commander", "remote"]

ARG VERSION=0.2.0
ARG VCS_REF=unknown
LABEL org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$VCS_REF"
LABEL org.opencontainers.image.source="https://github.com/egori4/cybercontroller-rdc-client" \
      io.egori4.project="cybercontroller-rdc-client" \
      io.egori4.security-profile="restricted"
