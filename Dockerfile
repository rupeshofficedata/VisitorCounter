# syntax=docker/dockerfile:1

# --- builder stage: installs deps, never ships to the final image ---
FROM python:3.13-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user -r requirements.txt

# --- final stage: base image + installed packages + app code only ---
FROM python:3.13-slim

# Set environment variables to optimize Python for container environments
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/appuser/.local/bin:$PATH

# Create a non-root system user and home workspace layout
RUN useradd --create-home --shell /bin/bash appuser

# Set the working directory context
WORKDIR /home/appuser/app

# Bring in only the installed packages from the builder stage
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# Copy the rest of your application code
COPY --chown=appuser:appuser . .

# Force the runtime environment to drop root access privileges
USER appuser

# Expose your application port (change if your app uses a different port, e.g., 5000 or 8000)
EXPOSE 5000

# Run your visitor counter script
CMD ["python", "app.py"]
