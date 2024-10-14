#!/bin/bash
set -e

# Set default environment variables
ARCH="${ARCH:-amd64}"
ALPINE_VERSION="${ALPINE_VERSION:-3.20.3}"
IMAGE_NAME="${IMAGE_NAME:-quay.io/deamen/alpine-base-${ARCH}}"

# Convert amd64 to x86_64 and arm64 to aarch64 for Alpine website
if [ "$ARCH" = "amd64" ]; then
    ARCH="x86_64"
elif [ "$ARCH" = "arm64" ]; then
    ARCH="aarch64"
fi

# Extract major and minor version from ALPINE_VERSION (e.g., 3.20 from 3.20.3)
ALPINE_MAJOR_MINOR_VERSION=$(echo "${ALPINE_VERSION}" | cut -d'.' -f1,2)

# Variables for tarball and verification, using the major and minor version in the URL
TARBALL_URI="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_MAJOR_MINOR_VERSION}/releases/${ARCH}"
TARBALL_CHECKSUM_URI="${TARBALL_URI}"
TARBALL_CHECKSUM_FILE="alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz.sha256"
TARBALL_FILE="alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"
TARBALL_GPG_KEY="ncopa.asc"
TARBALL_GPG_URI="https://alpinelinux.org/keys"
TARBALL_SIGNATURE="${TARBALL_FILE}.asc"
TARBALL_SIGNATURE_URI="${TARBALL_URI}"

# Debugging: Display the ARCH and TARBALL_URI to verify correctness
echo "ARCH: ${ARCH}"
echo "TARBALL_URI: ${TARBALL_URI}"

# Step 1: Create a new builder container with the correct architecture using --arch
echo "Creating builder container for verification with arch ${ARCH}..."
BUILDER_CONTAINER=$(buildah from --arch "${ARCH}" alpine:${ALPINE_VERSION})
buildah run "${BUILDER_CONTAINER}" -- apk add --no-cache wget gnupg

# Step 2: Download tarball, checksum, signature, and GPG key inside the container using wget
echo "Downloading Alpine tarball and verification files..."
buildah run "${BUILDER_CONTAINER}" -- sh -c "wget ${TARBALL_URI}/${TARBALL_FILE} \
  && wget ${TARBALL_CHECKSUM_URI}/${TARBALL_CHECKSUM_FILE} \
  && wget ${TARBALL_SIGNATURE_URI}/${TARBALL_SIGNATURE} \
  && wget ${TARBALL_GPG_URI}/${TARBALL_GPG_KEY}"

# Step 3: Import GPG key inside the container
echo "Importing GPG key..."
buildah run "${BUILDER_CONTAINER}" -- gpg --import "${TARBALL_GPG_KEY}"

# Step 4: Verify tarball checksum inside the container
echo "Verifying tarball checksum..."
buildah run "${BUILDER_CONTAINER}" -- sha256sum -c "${TARBALL_CHECKSUM_FILE}"

# Step 5: Verify tarball signature inside the container
echo "Verifying tarball GPG signature..."
buildah run "${BUILDER_CONTAINER}" -- gpg --verify "${TARBALL_SIGNATURE}" "${TARBALL_FILE}"

# Step 6: Create the copy script to copy the tarball from the mounted builder container
copy_script="copy_tarball.sh"
cat << 'EOF' >> $copy_script
#!/bin/sh
BUILDER_CONTAINER=$1
TARBALL_FILE=$2
TMP_DIR=$3

mnt=$(buildah mount $BUILDER_CONTAINER)
cp $mnt/$TARBALL_FILE $TMP_DIR/
buildah umount $BUILDER_CONTAINER
EOF
chmod a+x $copy_script

# Step 7: Use buildah unshare to copy the tarball from the builder container to the host
echo "Copying the tarball from the builder container to the host..."
TMP_DIR=$(mktemp -d)
buildah unshare ./$copy_script "$BUILDER_CONTAINER" "$TARBALL_FILE" "$TMP_DIR"

# Step 8: Create a new container from scratch and add the verified tarball
echo "Creating final container from verified tarball..."
FINAL_CONTAINER=$(buildah from --arch "${ARCH}" scratch)  # Ensure correct arch for final container
buildah add "${FINAL_CONTAINER}" "${TMP_DIR}/${TARBALL_FILE}" /

# Step 9: Update all packages in the final container
echo "Updating all packages inside the final container..."
buildah run "${FINAL_CONTAINER}" -- /bin/sh -c "apk update && apk upgrade --no-cache"

# Step 10: Commit the final container to a new image, squashing layers
echo "Committing the final container to ${IMAGE_NAME} with squash..."
buildah commit --squash "${FINAL_CONTAINER}" "${IMAGE_NAME}"  # Ensure arch on commit

# Step 11: Clean up
echo "Cleaning up..."
rm -rf "${TMP_DIR}" ./$copy_script
buildah rm "${BUILDER_CONTAINER}" "${FINAL_CONTAINER}"

echo "Alpine container image built successfully: ${IMAGE_NAME}"
