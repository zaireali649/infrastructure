# Multi-stage build for ML inference container with uv
FROM python:3.11-slim as builder

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_CACHE_DIR=/tmp/uv-cache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install --no-cache-dir uv

# Set work directory
WORKDIR /app

# Copy project files for dependency resolution
COPY pyproject.toml uv.lock ./

# Create virtual environment and install dependencies
RUN uv venv /opt/venv && \
    uv sync --frozen --no-dev --no-install-project && \
    rm -rf /tmp/uv-cache

# Production stage
FROM python:3.11-slim as production

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH="/opt/ml/code:$PYTHONPATH"

# Install system dependencies for production
RUN apt-get update && apt-get install -y \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Create necessary directories
RUN mkdir -p /opt/ml/code /opt/ml/processing/input /opt/ml/processing/output

# Copy application code
COPY app/ /opt/ml/code/

# Set working directory
WORKDIR /opt/ml/code

# Create non-root user for security
RUN groupadd -r ml && useradd -r -g ml -d /opt/ml -s /bin/bash ml
RUN chown -R ml:ml /opt/ml
USER ml

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import sys; print(f'Python: {sys.version}'); import mlflow, boto3; print('Dependencies OK')" || exit 1

# Default command
ENTRYPOINT ["python", "inference.py"]