FROM node:22.23.3-bookworm-slim

ARG DESKTOP_COMMANDER_VERSION=latest

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

WORKDIR /opt/rdc-client
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN printf '%s\n' '#!/bin/sh' 'exec node /opt/rdc-client/src/mcpctl.mjs "$@"' > /usr/local/bin/mcpctl \
 && chmod 0755 /usr/local/bin/mcpctl /usr/local/bin/docker-entrypoint.sh \
 && useradd --uid 10001 --user-group --create-home --home-dir /home/rdc --shell /bin/sh rdc \
 && mkdir -p /home/rdc/.desktop-commander-device /home/rdc/.claude-server-commander /home/rdc/.npm /run/rdc-client \
 && chown -R 10001:10001 /home/rdc /run/rdc-client

USER 10001:10001
WORKDIR /home/rdc

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["desktop-commander", "remote"]
