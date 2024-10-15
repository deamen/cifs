#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# ----------------------------------
# Configuration and Environment Setup
# ----------------------------------

# Default environment variables
ARCH=${ARCH:-amd64}
IMAGE_NAME=${IMAGE_NAME:-quay.io/deamen/caddy-${ARCH}}
CADDY_VERSION=${CADDY_VERSION:-2.8.4}

# URLs for downloading Caddy and related files
BASE_URL="https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}"
CADDY_PEM="${BASE_URL}/caddy_${CADDY_VERSION}_linux_${ARCH}.pem"
CADDY_TAR="${BASE_URL}/caddy_${CADDY_VERSION}_linux_${ARCH}.tar.gz"
CADDY_TAR_SIG="${BASE_URL}/caddy_${CADDY_VERSION}_linux_${ARCH}.tar.gz.sig"
CHECKSUMS="${BASE_URL}/caddy_${CADDY_VERSION}_checksums.txt"
CHECKSUMS_PEM="${BASE_URL}/caddy_${CADDY_VERSION}_checksums.txt.pem"
CHECKSUMS_SIG="${BASE_URL}/caddy_${CADDY_VERSION}_checksums.txt.sig"

# ----------------------------------
# Builder Stage: Download and Verify
# ----------------------------------

echo "Creating builder container from base image..."
builder=$(buildah from --arch "${ARCH}" quay.io/deamen/alpine-base:latest)

echo "Updating package index and installing necessary packages in builder..."
buildah run $builder -- apk update
buildah run $builder -- apk add --no-cache wget cosign

echo "Downloading Caddy binaries and verification files..."
buildah run $builder -- wget -O /tmp/caddy_${CADDY_VERSION}_linux_${ARCH}.pem "$CADDY_PEM"
buildah run $builder -- wget -O /tmp/caddy_${CADDY_VERSION}_linux_${ARCH}.tar.gz "$CADDY_TAR"
buildah run $builder -- wget -O /tmp/caddy_${CADDY_VERSION}_linux_${ARCH}.tar.gz.sig "$CADDY_TAR_SIG"
buildah run $builder -- wget -O /tmp/caddy_${CADDY_VERSION}_checksums.txt "$CHECKSUMS"
buildah run $builder -- wget -O /tmp/caddy_${CADDY_VERSION}_checksums.txt.pem "$CHECKSUMS_PEM"
buildah run $builder -- wget -O /tmp/caddy_${CADDY_VERSION}_checksums.txt.sig "$CHECKSUMS_SIG"

# ----------------------------------
# Decode PEM and Verify Signatures Using Cosign
# ----------------------------------

echo "Decoding the checksums PEM file..."
buildah run $builder -- sh -c "base64 -d < /tmp/caddy_${CADDY_VERSION}_checksums.txt.pem > /tmp/cert.pem"

echo "Verifying the checksums signature using cosign..."
buildah run $builder -- cosign verify-blob \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-github-workflow-name "Release" \
    --certificate-github-workflow-ref refs/tags/v${CADDY_VERSION} \
    --certificate-identity-regexp caddyserver/caddy \
    --certificate /tmp/cert.pem \
    --signature /tmp/caddy_${CADDY_VERSION}_checksums.txt.sig \
    --verbose /tmp/caddy_${CADDY_VERSION}_checksums.txt

echo "Using checksums file to verify the Caddy tarball..."
buildah run $builder -- sh -c "cd /tmp && grep caddy_${CADDY_VERSION}_linux_${ARCH}.tar.gz caddy_${CADDY_VERSION}_checksums.txt | sha512sum -c -"

echo "Decoding the Caddy tarball PEM file..."
buildah run $builder -- sh -c "base64 -d < /tmp/caddy_${CADDY_VERSION}_linux_${ARCH}.pem > /tmp/caddy_cert.pem"

echo "Verifying the Caddy tarball signature using cosign..."
buildah run $builder -- cosign verify-blob \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-github-workflow-name "Release" \
    --certificate-github-workflow-ref refs/tags/v${CADDY_VERSION} \
    --certificate-identity-regexp caddyserver/caddy \
    --certificate /tmp/caddy_cert.pem \
    --signature /tmp/caddy_${CADDY_VERSION}_linux_${ARCH}.tar.gz.sig \
    --verbose /tmp/caddy_${CADDY_VERSION}_linux_${ARCH}.tar.gz

echo "Extracting the Caddy binary from the tarball..."
buildah run $builder -- tar -xzvf /tmp/caddy_${CADDY_VERSION}_linux_${ARCH}.tar.gz -C /tmp

# ----------------------------------
# Final Stage: Assemble the Image
# ----------------------------------

echo "Creating final image container from base image..."
final=$(buildah from --arch "${ARCH}" quay.io/deamen/alpine-base:latest)

echo "Updating package index and installing necessary packages in final image..."
buildah run $final -- apk update
buildah run $final -- apk add --no-cache ca-certificates libcap mailcap wget

echo "Copying the verified Caddy binary from the builder to the final image..."
buildah copy --from=$builder $final /tmp/caddy /usr/bin/caddy
buildah run $final -- chmod +x /usr/bin/caddy

echo "Configuring environment variables in the final image..."
buildah config --env XDG_CONFIG_HOME=/config $final
buildah config --env XDG_DATA_HOME=/data $final

echo "Creating necessary directories in the final image..."
buildah run $final -- mkdir -p /config/caddy /data/caddy /etc/caddy /usr/share/caddy

echo "Downloading the default index.html for Caddy..."
buildah run $final -- wget -O /usr/share/caddy/index.html "https://github.com/caddyserver/dist/raw/509c30cecd3cbc4012f6b1cc88d8f3f000fb06e4/welcome/index.html"

echo "Adding metadata labels to the final image..."
buildah config --label org.opencontainers.image.version=v${CADDY_VERSION} \
    --label org.opencontainers.image.title=Caddy \
    --label org.opencontainers.image.description="A powerful, enterprise-ready, open source web server with automatic HTTPS written in Go" \
    --label org.opencontainers.image.url=https://caddyserver.com \
    --label org.opencontainers.image.documentation=https://caddyserver.com/docs \
    --label org.opencontainers.image.vendor="quay.io/deamen" \
    --label org.opencontainers.image.licenses=Apache-2.0 \
    --label org.opencontainers.image.source="https://github.com/deamen/cifs" \
    $final

echo "Exposing necessary network ports..."
buildah config --port 80 --port 443 --port 443/udp --port 2019 $final

echo "Setting the working directory to /srv..."
buildah config --workingdir /srv $final

echo "Defining the container's entrypoint command..."
buildah config --cmd '["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]' $final

# ----------------------------------
# Commit and Cleanup
# ----------------------------------

echo "Committing the final image with squash to reduce size..."
buildah commit --squash $final $IMAGE_NAME

echo "Removing intermediate containers..."
buildah rm $builder || true
buildah rm $final || true

echo "Container image built successfully: $IMAGE_NAME"
