#!/bin/bash

# Exit on error
set -e

# Set environment variables with defaults
ARCH="${ARCH:-amd64}"
IMAGE_NAME="${IMAGE_NAME:-quay.io/deamen/qpkg-builder-${ARCH}}"
QDK_VERSION="${QDK_VERSION:-2.3.14}"

# Define source URL
QDK_URL="https://github.com/qnap-dev/QDK/archive/refs/tags/v${QDK_VERSION}.zip"

# Use buildah to create a multi-stage build
builder=$(buildah from --arch "${ARCH}" quay.io/deamen/alpine-base:latest)

# Set build container
buildah run "$builder" -- apk add --no-cache build-base git bash curl wget openssl rsync

# Download QDK source
buildah run "$builder" -- wget -O /tmp/QDK.zip "${QDK_URL}"

# Unzip QDK.zip to /tmp
buildah run "$builder" -- unzip /tmp/QDK.zip -d /tmp/

# Apply patches to InstallToUbuntu.sh
buildah run "$builder" -- sed -i 's/apt-get update/echo "Do nothing in Alpine"/g' /tmp/QDK-${QDK_VERSION}/InstallToUbuntu.sh
buildah run "$builder" -- sed -i '/apt-get/d' /tmp/QDK-${QDK_VERSION}/InstallToUbuntu.sh

# Change to /tmp/QDK-${QDK_VERSION} and run InstallToUbuntu.sh install
buildah run "$builder" -- bash -c "cd /tmp/QDK-${QDK_VERSION} && ./InstallToUbuntu.sh install"

# Create final image stage
final=$(buildah from --arch "${ARCH}" quay.io/deamen/alpine-base:latest)

# Install necessary packages in the final image, including gpg and gpg-agent
buildah run "$final" -- apk add --no-cache bash curl wget openssl rsync gpg gpg-agent

# Set up workdir and create necessary directories
buildah run "$final" -- mkdir -p /SRC

# Copy installed QDK files, /bin/qpkg_encrypt, and /etc/config from builder to final image
buildah copy --from="$builder" "$final" /usr/share/QDK /usr/share/QDK
buildah copy --from="$builder" "$final" /bin/qpkg_encrypt /bin/qpkg_encrypt
buildah copy --from="$builder" "$final" /etc/config /etc/config

# Set workdir
buildah config --workingdir /SRC "$final"

# Append PATH and QDK_SIGNATURE to ~/.bashrc in the final image
buildah run "$final" -- bash -c 'echo "PATH=\$PATH:/usr/share/QDK/bin" >> ~/.bashrc'
buildah run "$final" -- bash -c 'echo "export QDK_SIGNATURE=gpg" >> ~/.bashrc'

# Source ~/.bashrc before running CMD
buildah config --cmd '["bash", "-c", "source ~/.bashrc && /usr/share/QDK/bin/qbuild"]' "$final"

# Add labels
buildah config --label org.opencontainers.image.version="v${QDK_VERSION}" "$final"
buildah config --label org.opencontainers.image.title="QDK" "$final"
buildah config --label org.opencontainers.image.description="QDK is used to build QPKG files/applications for QNAP Turbo NAS." "$final"
buildah config --label org.opencontainers.image.url="https://github.com/qnap-dev/QDK" "$final"
buildah config --label org.opencontainers.image.documentation="QDK/README.md at master · qnap-dev/QDK (github.com)" "$final"
buildah config --label org.opencontainers.image.vendor="quay.io/deamen" "$final"
buildah config --label org.opencontainers.image.licenses="GPL-3.0-only" "$final"
buildah config --label org.opencontainers.image.source="https://github.com/deamen/cifs" "$final"

# Commit and squash the final image
buildah commit --squash "$final" "${IMAGE_NAME}"

# Clean up
buildah rm "$builder" "$final"

echo "Image ${IMAGE_NAME} has been built and squashed successfully!"