#!/bin/bash

set -e  # Exit on error

##
# Image name should be the full name of the image, e.g., quay.io/deamen/alpine-base
##

# Ensure image name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <image-name>"
  exit 1
fi

# Variables
IMAGE_NAME=$1
ARCH_AMD64="amd64"
ARCH_ARM64="arm64"

# Create a multi-arch manifest
buildah manifest create ${IMAGE_NAME}

# Build images for both architectures and add them to the manifest
buildah manifest add ${IMAGE_NAME} ${IMAGE_NAME}-${ARCH_AMD64}
buildah manifest add ${IMAGE_NAME} ${IMAGE_NAME}-${ARCH_ARM64}

buildah manifest push --all ${IMAGE_NAME} docker://${IMAGE_NAME}:latest

# Remove manifest after pushing
buildah manifest rm ${IMAGE_NAME}