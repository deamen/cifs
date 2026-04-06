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

# Create default user and allow passwordless sudo
buildah run "$ctr" useradd -m ${MAINTAINER}
buildah run "$ctr" sh -c "echo '${MAINTAINER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${MAINTAINER}"
buildah run "$ctr" chmod 0440 /etc/sudoers.d/${MAINTAINER}

# Set the default user and working directory for the container
buildah config --user ${MAINTAINER} "$ctr"
buildah config --workingdir /home/${MAINTAINER} "$ctr"

# Fix sudo PAM account management for container environments (e.g. GitHub Actions)
buildah run --user root "$ctr" sh -c 'printf "#%%PAM-1.0\nauth       include      system-auth\naccount    sufficient   pam_permit.so\nsession    optional     pam_keyinit.so revoke\nsession    required     pam_limits.so\n" > /etc/pam.d/sudo'

echo "Preparing Ansible project in the container..."
prepare_ansible_project_in_container "$ctr"

echo "Running Ansible playbooks to configure the container..."
buildah run "$ctr" sh -c "source /etc/profile.d/user_home_local_bin.sh && cd Prj/ansible && ansible-playbook -i localhost, playbooks/configure_ansible_development_env.yml --limit localhost --connection local"

buildah run "$ctr" rm -rf /home/${MAINTAINER}/Prj/ansible

# Set the default command to login shell
set_default_cmd $ctr "/bin/bash --login"

commit_and_squash $ctr ${IMAGE_NAME}

# Remove the container after committing the image
buildah rm $ctr
