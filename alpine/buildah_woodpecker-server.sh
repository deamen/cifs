#!/bin/bash
set -e  # Exit on error

# Variables
WOODPECKER_VERSION=${WOODPECKER_VERSION:-2.7.1}
ARCH=${ARCH:-amd64}
ALPINE_VERSION=${ALPINE_VERSION:-3.20.3}
TAR_FILE="woodpecker-server_linux_${ARCH}.tar.gz"
CHECKSUM_FILE="checksums.txt"
QUAY_IMAGE="quay.io/deamen/woodpecker-server-${ARCH}"

# Step 1: Create the builder container
builder=$(buildah from alpine:${ALPINE_VERSION})

# Step 2: Install necessary tools for builder
buildah run $builder apk add --no-cache curl openssl tar

# Step 3: Download the tarball and checksums
echo "Downloading tarball and checksum file..."
buildah run $builder curl -L -o /tmp/${TAR_FILE} https://github.com/woodpecker-ci/woodpecker/releases/download/v${WOODPECKER_VERSION}/${TAR_FILE}
buildah run $builder curl -L -o /tmp/${CHECKSUM_FILE} https://github.com/woodpecker-ci/woodpecker/releases/download/v${WOODPECKER_VERSION}/${CHECKSUM_FILE}

# Verify that files are downloaded
echo "Checking if tarball and checksum files exist..."
buildah run $builder ls -l /tmp/${TAR_FILE} /tmp/${CHECKSUM_FILE}

# Step 4: Verify checksum
echo "Verifying checksum..."
buildah run $builder sh -c "cd /tmp && grep ${TAR_FILE} ${CHECKSUM_FILE} | sha256sum -c -"

# Step 5: Extract tarball
echo "Extracting tarball..."
buildah run $builder tar -xzf /tmp/${TAR_FILE} -C /tmp

# Check extracted files and their location
echo "Listing extracted contents..."
buildah run $builder ls -l /tmp

# Step 6: Create the final image
final_image=$(buildah from alpine:${ALPINE_VERSION})
echo "Building final image..."

# Step 7: Copy woodpecker binary from the builder container to the final image
echo "Copying woodpecker binary from builder container..."
buildah copy --from=$builder $final_image /tmp/woodpecker-server /usr/local/bin/

# Step 8: Set entrypoint and labels
echo "Setting entrypoint and labels..."
buildah config --cmd '[]' $final_image
buildah config --entrypoint '["/usr/local/bin/woodpecker-server"]' $final_image

buildah config --label version=${WOODPECKER_VERSION} $final_image

# Step 9: Commit the final image
echo "Committing the final image..."
buildah commit --squash $final_image ${QUAY_IMAGE}

# Clean up
echo "Cleaning up..."
buildah rm $builder $final_image