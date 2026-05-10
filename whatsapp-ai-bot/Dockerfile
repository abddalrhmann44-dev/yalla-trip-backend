FROM node:20-alpine

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

WORKDIR /app

# Copy dependency manifests first (layer cache)
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# Copy source
COPY src/ ./src/

# Non-root user for security
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -s /bin/sh -D appuser && \
    chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

# dumb-init ensures signals (SIGTERM) are forwarded to Node
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/app.js"]
