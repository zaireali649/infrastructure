# Single-stage build for ML training container with uv
FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_CACHE_DIR=/tmp/uv-cache \
    PYTHONPATH="/opt/ml/code:$PYTHONPATH"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install --no-cache-dir uv

# Set work directory
WORKDIR /app

# Copy project files for dependency resolution
COPY pyproject.toml uv.lock ./

# Export dependencies and install globally (exclude local project)
RUN uv export --frozen --no-dev --format requirements-txt --no-hashes > requirements.txt && \
    pip install --no-cache-dir -r requirements.txt && \
    rm requirements.txt && \
    rm -rf /tmp/uv-cache

# Create necessary directories
RUN mkdir -p /opt/ml/code /opt/ml/input /opt/ml/model /opt/ml/output /opt/ml/processing/output

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
    CMD python -c "import sys; print(f'Python: {sys.version}'); import sklearn, mlflow, pandas; print('Dependencies OK')" || exit 1

# Default command
ENTRYPOINT ["python", "train.py"]