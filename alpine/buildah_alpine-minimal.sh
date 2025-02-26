#!/bin/bash

# Set default architecture to amd64 if not provided
ARCH=${ARCH:-amd64}

# Create a new container from the alpine-base image with specified architecture
ctr=$(buildah from --arch $ARCH quay.io/deamen/alpine-base:latest)

# Set the maintainer label
buildah config --label maintainer="Song Tang" $ctr

# Update and upgrade the Alpine packages
buildah run $ctr apk update
buildah run $ctr apk upgrade --no-cache

# Set the default command for the container
buildah config --cmd "/bin/sh" $ctr

# Commit the container to an image with squashing layers
buildah commit --squash $ctr quay.io/deamen/alpine-minimal-${ARCH}

# Remove the container after committing the image
buildah rm $ctr
