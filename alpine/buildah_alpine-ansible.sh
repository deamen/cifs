#!/bin/bash
set -e

# openssh-client is needed for ansible to connect to remote hosts
ANSIBLE_PACKAGES="ansible ansible-lint openssh-client pre-commit pipx git git-prompt"
ANSIBLE_PIP_PACKAGES="detect-secrets"

source "$(dirname "$0")/alpine_vars.sh"
IMAGE_NAME=${IMAGE_NAME:-${REGISTRY_URL}/alpine-ansible-${ARCH}}

# Create a new container from the alpine-base image with specified architecture
ctr=$(eval "$MINIMAL_CONTAINER")


doas_add_packages $ctr ${ANSIBLE_PACKAGES}
doas_add_user_home_local_bin $ctr
install_pipx_packages $ctr ${ANSIBLE_PIP_PACKAGES}
configure_git_prompt $ctr

# Set the default command to login shell
set_default_cmd $ctr "/bin/ash --login"

commit_and_squash $ctr ${IMAGE_NAME}

# Remove the container after committing the image
buildah rm $ctr
