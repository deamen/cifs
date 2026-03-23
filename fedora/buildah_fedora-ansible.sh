#!/bin/bash
set -e

# openssh-clients is needed for ansible to connect to remote hosts
ANSIBLE_PACKAGES="ansible ansible-lint openssh-clients pre-commit pipx git sudo"
ANSIBLE_PIP_PACKAGES="detect-secrets"

source "$(dirname "$0")/fedora_vars.sh"
IMAGE_NAME=${IMAGE_NAME:-${REGISTRY_URL}/fedora-ansible-${ARCH}}

# Create a new container from the fedora-minimal image with specified architecture
ctr=$(eval "$MINIMAL_CONTAINER")

add_packages $ctr ${ANSIBLE_PACKAGES}

# Add ~/.local/bin to PATH for all users
buildah run "$ctr" sh -c "echo 'export PATH=\$PATH:~/.local/bin' > /etc/profile.d/user_home_local_bin.sh"
buildah run "$ctr" chmod 0644 /etc/profile.d/user_home_local_bin.sh

install_pipx_packages $ctr ${ANSIBLE_PIP_PACKAGES}
configure_git_prompt $ctr

# Create default user and allow passwordless sudo
buildah run "$ctr" useradd -m ${MAINTAINER}
buildah run "$ctr" sh -c "echo '${MAINTAINER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${MAINTAINER}"
buildah run "$ctr" chmod 0440 /etc/sudoers.d/${MAINTAINER}

# Set the default user and working directory for the container
buildah config --user ${MAINTAINER} "$ctr"
buildah config --workingdir /home/${MAINTAINER} "$ctr"

# Set the default command to login shell
set_default_cmd $ctr "/bin/bash --login"

commit_and_squash $ctr ${IMAGE_NAME}

# Remove the container after committing the image
buildah rm $ctr
