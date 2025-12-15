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