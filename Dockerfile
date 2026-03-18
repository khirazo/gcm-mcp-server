# GCM MCP Server - Stdio Mode Dockerfile
# Optimized for laptop deployment with IBM Bob MCP client

# ============================================================
# Stage 1: Builder - Install Python dependencies
# ============================================================
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ============================================================
# Stage 2: Runtime - Minimal production image
# ============================================================
FROM python:3.11-slim

# Create non-root user for security
RUN groupadd -r gcm && useradd -r -g gcm -u 1000 gcm

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /root/.local /home/gcm/.local

# Copy application code
COPY --chown=gcm:gcm src ./src

# Copy scripts
COPY --chown=gcm:gcm scripts/entrypoint.sh /entrypoint.sh
COPY --chown=gcm:gcm scripts/config-loader.py /config-loader.py

# Make scripts executable
RUN chmod +x /entrypoint.sh /config-loader.py

# Set environment variables
ENV PATH=/home/gcm/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

# Switch to non-root user
USER gcm

# Use entrypoint script for configuration loading and validation
ENTRYPOINT ["/entrypoint.sh"]

# Default to stdio transport mode
CMD ["stdio"]