ARCH=${ARCH:-amd64}
BASE_IMAGE="quay.io/deamen/alpine-base:latest"
MINIMAL_IMAGE="quay.io/deamen/alpine-minimal:latest"
MINIMAL_CONTAINER="buildah from --arch $ARCH $MINIMAL_IMAGE"
BASE_CONTAINER="buildah from --arch $ARCH $BASE_IMAGE"
MAINTAINER="deamen"
REGISTRY_URL="quay.io/deamen"

set_maintainer_label() {
    local ctr="$1"
    buildah config --label maintainer=${MAINTAINER} "$ctr"
}

update_and_upgrade_packages() {
    echo "Updating and upgrading packages in container $1..."
    local ctr="$1"
    buildah run "$ctr" apk update
    buildah run "$ctr" apk upgrade --no-cache
}

commit_and_squash() {
    echo "Committing and squashing container $1 into image $2 ..."
    local ctr="$1"
    local image_name="$2"
    buildah commit --squash "$ctr" "${image_name}"
}

doas_add_packages() {
    echo "Adding packages: $2 to container $1 ..."
    local ctr="$1"
    shift
    local packages=("$@")
    buildah run "$ctr" doas apk add --no-cache "${packages[@]}"
}

install_pipx_packages() {
    echo "Installing pip packages: $2 to container $1 ..."
    local ctr="$1"
    shift
    local packages=("$@")
    buildah run "$ctr" pipx install "${packages[@]}"
}

doas_add_user_home_local_bin() {
    echo "Adding user home bin directory to PATH in container $1 ..."
    local ctr="$1"
    buildah run "$ctr" sh -c "echo 'export PATH=\$PATH:~/.local/bin' > /tmp/user_home_local_bin.sh"
    buildah run "$ctr" chmod 0644 /tmp/user_home_local_bin.sh
    buildah run "$ctr" doas mv /tmp/user_home_local_bin.sh /etc/profile.d/user_home_local_bin.sh
    buildah run "$ctr" doas chown root:root /etc/profile.d/user_home_local_bin.sh
}

set_default_cmd() {
    echo "Setting default command for container $1 to $2 ..."
    local ctr="$1"
    local cmd="$2"
    buildah config --cmd "$cmd" "$ctr"
}

configure_git_prompt() {
    echo "Configuring git prompt in container $1 ..."
    local ctr="$1"
    buildah copy "$ctr" "$(dirname "$0")/files/load_git-prompt.sh" /etc/profile.d/load_git-prompt.sh
    buildah run "$ctr" doas chmod 0644 /etc/profile.d/load_git-prompt.sh
}