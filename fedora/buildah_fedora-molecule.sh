#!/bin/bash
set -e

MOLECULE_PACKAGES="sudo python3-dnf python3-libdnf5"

source "$(dirname "$0")/fedora_vars.sh"
IMAGE_NAME=${IMAGE_NAME:-${REGISTRY_URL}/fedora-molecule-${ARCH}}

# Create a new container from the fedora init image with specified architecture
ctr=$(eval "$INIT_CONTAINER")

set_maintainer_label $ctr

add_packages $ctr ${MOLECULE_PACKAGES}

commit_and_squash $ctr ${IMAGE_NAME}

# Remove the container after committing the image
buildah rm $ctr
