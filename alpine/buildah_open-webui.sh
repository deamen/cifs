#!/bin/bash

set -e

# ----------------------------------
# Configuration and Environment Setup
# ----------------------------------

ARCH=${ARCH:-amd64}
IMAGE_NAME=${IMAGE_NAME:-quay.io/deamen/open-webui-${ARCH}}
PYTHON_VERSION=${PYTHON_VERSION:-3.11}
PYTHON_PKG="python${PYTHON_VERSION}"
PIP_PKG="py${PYTHON_VERSION/./}-pip"

# ----------------------------------
# Single-Stage: Install Python and Open-WebUI
# ----------------------------------

echo "Creating container from base image..."
container=$(buildah from --arch "${ARCH}" quay.io/deamen/alpine-base:latest)

echo "Updating package index and installing necessary packages..."
buildah run $container -- apk update
buildah run $container -- apk add --no-cache $PYTHON_PKG $PIP_PKG dumb-init ca-certificates bash

# Set up Python virtual environment using the specified Python version
echo "Setting up Python virtual environment..."
buildah run $container -- /usr/bin/python${PYTHON_VERSION} -m venv /open_webui_pyvenv
buildah run $container -- /open_webui_pyvenv/bin/pip install --no-cache-dir --upgrade pip

# Install open-webui
echo "Installing open-webui..."
buildah run $container -- /open_webui_pyvenv/bin/pip install --no-cache-dir open-webui

# Configure environment variables
buildah config --env VIRTUAL_ENV=/open_webui_pyvenv $container
buildah config --env PATH="/open_webui_pyvenv/bin:$PATH" $container
buildah config --env TZ=Australia/Melbourne $container

# Expose necessary ports
buildah config --port 8080 $container

# Set entrypoint and command
buildah config --entrypoint '["/usr/bin/dumb-init", "--"]' $container
buildah config --cmd '["bash", "-c", "exec open-webui serve --host 0.0.0.0 --port 8080"]' $container

# Commit and Cleanup
echo "Committing the image..."
buildah commit --squash $container $IMAGE_NAME

echo "Removing container..."
buildah rm $container || true

echo "Container image built successfully: $IMAGE_NAME"