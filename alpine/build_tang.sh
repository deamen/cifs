#!/bin/bash

# Exit on error
set -e

# Set variables for version numbers
ALPINE_VERSION=3.20.3
JOSE_VERSION=14
TANG_VERSION=15

# Create the base builder container using the Alpine version variable
builder=$(buildah from alpine:$ALPINE_VERSION)

# Install necessary build dependencies, including xz for extracting .tar.xz files
buildah run $builder -- apk add --no-cache --update \
    bash \
    g++ gawk git gmp gzip \
    http-parser-dev \
    isl-dev \
    jansson-dev \
    meson mpc1-dev mpfr-dev musl-dev \
    ninja \
    openssl-dev \
    tar \
    zlib-dev \
    curl \
    xz  # Added xz to handle .tar.xz files

# Download and verify the JOSE tarball
buildah run $builder -- sh -c "curl -L https://github.com/latchset/jose/releases/download/v$JOSE_VERSION/jose-$JOSE_VERSION.tar.xz -o /tmp/jose-$JOSE_VERSION.tar.xz"
buildah run $builder -- sh -c "curl -L https://github.com/latchset/jose/releases/download/v$JOSE_VERSION/jose-$JOSE_VERSION.tar.xz.sha256sum -o /tmp/jose-$JOSE_VERSION.tar.xz.sha256sum"
buildah run $builder -- sh -c "cd /tmp && sha256sum -c jose-$JOSE_VERSION.tar.xz.sha256sum"

# Extract, build, and install JOSE
buildah run $builder -- sh -c "cd /tmp && tar -xf jose-$JOSE_VERSION.tar.xz && cd jose-$JOSE_VERSION && mkdir build && cd build && meson .. --prefix=/usr/local && ninja install"

# Download and verify the Tang tarball
buildah run $builder -- sh -c "curl -L https://github.com/latchset/tang/releases/download/v$TANG_VERSION/tang-$TANG_VERSION.tar.xz -o /tmp/tang-$TANG_VERSION.tar.xz"
buildah run $builder -- sh -c "curl -L https://github.com/latchset/tang/releases/download/v$TANG_VERSION/tang-$TANG_VERSION.tar.xz.sha256sum -o /tmp/tang-$TANG_VERSION.tar.xz.sha256sum"
buildah run $builder -- sh -c "cd /tmp && sha256sum -c tang-$TANG_VERSION.tar.xz.sha256sum"

# Extract, build, and install Tang
buildah run $builder -- sh -c "cd /tmp && tar -xf tang-$TANG_VERSION.tar.xz && cd tang-$TANG_VERSION && mkdir build && cd build && meson .. --prefix=/usr/local && ninja install"

# Create the final container image using the Alpine version variable
final=$(buildah from alpine:$ALPINE_VERSION)

# Copy the built JOSE and Tang binaries from the builder container to the final container
buildah copy --from=$builder $final /usr/local/bin/jose /usr/local/bin/
buildah copy --from=$builder $final /usr/local/libexec/tangd /usr/local/bin/
buildah copy --from=$builder $final /usr/local/libexec/tangd-keygen /usr/local/bin/
buildah copy --from=$builder $final /usr/local/libexec/tangd-rotate-keys /usr/local/bin/
buildah copy --from=$builder $final /usr/local/bin/tang-show-keys /usr/local/bin/
buildah copy --from=$builder $final /usr/local/lib/libjose.so* /usr/local/lib/

# Install runtime dependencies in the final container
buildah run $final -- apk add --no-cache --update \
    http-parser \
    jansson \
    openssl \
    wget \
    zlib

# Expose the new Tang port (7500) and configure a volume for the database
buildah config --port 7500 $final
buildah config --volume /db $final

# Directly run the Tang server in standalone mode (listening on port 7500)
buildah config --cmd '["tangd", "-l", "-p", "7500", "/db"]' $final

# Commit the final image with the new name
buildah commit $final nbde-tang-server
