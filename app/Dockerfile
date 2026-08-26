# -----------------------------------------
# Stage 1: Builder
# -----------------------------------------
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy dependency manifests first (layer cache optimization)
COPY package*.json ./

# Install ALL dependencies including devDependencies for testing
RUN npm ci

# Copy application source
COPY src/ ./src/
COPY tests/ ./tests/

# Run unit tests during build stage (fail fast)
RUN npm run test:unit

# -----------------------------------------
# Stage 2: Production Runtime
# -----------------------------------------
FROM node:20-alpine AS production

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only production dependencies manifest
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev && npm cache clean --force

# Copy application source from builder stage
COPY --from=builder /app/src ./src

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 3000

# Health check for Kubernetes liveness probe alignment
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

# Start application
CMD ["node", "src/index.js"]
