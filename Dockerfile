# ── Stage 1: Build ─────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files first
COPY backend/package*.json ./backend/

# Install production dependencies
WORKDIR /app/backend
RUN npm install --omit=dev

# ── Stage 2: Runtime ───────────────────────────────────────
FROM node:20-alpine

WORKDIR /app

# Copy backend dependencies
COPY --from=builder /app/backend/node_modules ./backend/node_modules

# Copy backend source
COPY backend/ ./backend/

# Copy frontend files
COPY frontend/ ./frontend/

# Security: non-root user
RUN addgroup -S appgroup -g 1001 && \
    adduser -S appuser -u 1001 -G appgroup

USER 1001

# App port
EXPOSE 5000

# ECS / ALB health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD wget -qO- http://localhost:5000/api/health || exit 1

# Start app
CMD ["node", "backend/server.js"]
