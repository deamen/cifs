#!/bin/bash
set -e

MOLECULE_PACKAGES="sudo python3-dnf python3-libdnf5"

source "$(dirname "$0")/fedora_vars.sh"
IMAGE_NAME=${IMAGE_NAME:-${REGISTRY_URL}/fedora-molecule-${ARCH}}

# Create a new container from the fedora base image with specified architecture
ctr=$(eval "$INIT_CONTAINER")

set_maintainer_label $ctr

add_packages $ctr ${MOLECULE_PACKAGES}

# Set default command to systemd init
buildah config --cmd "/sbin/init" "$ctr"
buildah config --stop-signal SIGRTMIN+3 "$ctr"

# Mask unnecessary systemd units (same as fedora-init)
buildah run "$ctr" systemctl mask \
    systemd-remount-fs.service \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    systemd-logind.service \
    getty.target \
    console-getty.service \
    systemd-udev-trigger.service \
    systemd-udevd.service \
    systemd-random-seed.service

commit_and_squash $ctr ${IMAGE_NAME}

# Remove the container after committing the image
buildah rm $ctr
