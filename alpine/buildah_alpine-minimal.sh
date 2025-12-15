#!/bin/bash
set -e

source "$(dirname "$0")/alpine_vars.sh"
IMAGE_NAME=${IMAGE_NAME:-${REGISTRY_URL}/alpine-minimal-${ARCH}}

# Create a new container from the alpine-base image with specified architecture
ctr=${BASE_CONTAINER}

set_maintainer_label $ctr

update_and_upgrade_packages $ctr

buildah run $ctr adduser --disabled-password ${MAINTAINER}
buildah run $ctr apk add --no-cache doas

# Allow the default user to execute commands as root using doas
buildah run $ctr sh -c "echo 'permit nopass ${MAINTAINER} as root' > /etc/doas.d/${MAINTAINER}.conf"

# Set the default user and working directory for the container
buildah config --user ${MAINTAINER} $ctr
buildah config --workingdir /home/${MAINTAINER} $ctr

# Set the default command for the container
buildah config --cmd "/bin/sh" $ctr

commit_and_squash $ctr ${IMAGE_NAME}

# Remove the container after committing the image
buildah rm $ctr
