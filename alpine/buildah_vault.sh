#!/bin/bash

# Exit on error
set -e

# Define architecture-specific variables
ARCH=${ARCH:-amd64}   # Default to amd64, can override with arm64 or others
PRODUCT=${PRODUCT:-vault}  # Replace with the actual default product or allow user to define it
VERSION=${VERSION:-1.18.0}  # Replace with the actual default version or allow user to define it
ALPINE_VERSION=${ALPINE_VERSION:-latest}  # Default Alpine version is 'latest'
NAME=${NAME:-vault}  # Replace with the actual default name or allow user to define it
IMAGE_NAME=${IMAGE_NAME:-quay.io/deamen/vault-${ARCH}}
BASE_IMAGE="quay.io/deamen/alpine-base:latest"

# Create the base builder container using the provided architecture
echo "Building for architecture: $ARCH"
builder=$(buildah from --arch $ARCH ${BASE_IMAGE})

# Install dependencies in the builder
buildah run $builder apk add --update --virtual .deps --no-cache gnupg git

# Create a temporary directory and switch to it
buildah run $builder mkdir /tmp/downloads
buildah config --workingdir /tmp/downloads $builder

# Download the product binary and related files
buildah run $builder wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_linux_${ARCH}.zip
buildah run $builder wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS
buildah run $builder wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig

# Import HashiCorp PGP key
buildah run $builder mkdir -p /root/.gnupg
buildah run $builder -- sh -c "wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import"

# Verify the downloaded files
buildah run $builder gpg --verify ${PRODUCT}_${VERSION}_SHA256SUMS.sig ${PRODUCT}_${VERSION}_SHA256SUMS
buildah run $builder -- sh -c "grep ${PRODUCT}_${VERSION}_linux_${ARCH}.zip ${PRODUCT}_${VERSION}_SHA256SUMS | sha256sum -c -"

# Unzip the product binary
buildah run $builder unzip /tmp/downloads/${PRODUCT}_${VERSION}_linux_${ARCH}.zip -d /tmp/downloads

# Move the binary to /usr/local/bin in the builder
buildah run $builder mv /tmp/downloads/${PRODUCT} /usr/local/bin/${PRODUCT}

# Copy entrypoint script from the vault repository
buildah run $builder git clone https://github.com/hashicorp/vault.git /tmp/vault
buildah config --workingdir /tmp/vault $builder
buildah run $builder git checkout v${VERSION}
buildah run $builder cp .release/docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Start a new container from alpine
final_image=$(buildah from --arch $ARCH ${BASE_IMAGE})

# Copy the product binary from the builder to the new container
buildah copy --from=$builder $final_image /usr/local/bin/${PRODUCT} /usr/local/bin/${PRODUCT}
buildah copy --from=$builder $final_image /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

buildah run $final_image apk add --no-cache libcap su-exec dumb-init tzdata
buildah run $final_image addgroup ${NAME} 
buildah run $final_image adduser -S -G ${NAME} ${NAME}

# /vault/logs is made available to use as a location to store audit logs, if
# desired; /vault/file is made available to use as a location with the file
# storage backend, if desired; the server will be started with /vault/config as
# the configuration directory so you can add additional config files in that
# location.
buildah run $final_image mkdir -p /vault/logs
buildah run $final_image mkdir -p /vault/file
buildah run $final_image mkdir -p /vault/data
buildah run $final_image mkdir -p /vault/tls
buildah run $final_image mkdir -p /vault/config
buildah run $final_image chown -R ${NAME}:${NAME} /vault

buildah config --volume /vault/logs $final_image
buildah config --volume /vault/file $final_image
buildah config --port 8200 $final_image

buildah config --entrypoint '["docker-entrypoint.sh"]' $final_image
# Commit the final image
buildah commit $final_image $IMAGE_NAME
