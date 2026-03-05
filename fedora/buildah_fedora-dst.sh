#!/bin/bash
set -e

STEAMCMD_PACKAGES="glibc.i686 tar gzip glibc-langpack-en"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
STEAMCMD_INSTALL_DIR="/usr/local/bin"
STEAMCMD_PATH="/usr/local/bin/steamcmd.sh"
# libcurl-gnutls is in patrickl/wine-tkg
DST_PACKAGES="libcurl-gnutls"
DST_USER_DATA_DIR="/opt/klei/dst_user_data"
DST_INSTALL_DIR="/opt/klei/dst"
DST_MODS_PATH="$DST_USER_DATA_DIR/mods"
DST_UGC_PATH="$DST_MODS_PATH/ugc"

source "$(dirname "$0")/fedora_vars.sh"
IMAGE_NAME=${IMAGE_NAME:-${REGISTRY_URL}/fedora-dst-${ARCH}}
# Create a new container from the alpine-base image with specified architecture
ctr=$(eval "$MINIMAL_CONTAINER")

buildah run $ctr dnf install dnf-plugins-core -y
buildah run $ctr dnf4 copr enable patrickl/wine-tkg -y
add_packages $ctr ${STEAMCMD_PACKAGES}
add_packages $ctr ${DST_PACKAGES}

# Install and update SteamCMD
buildah run $ctr sh -c "cd $STEAMCMD_INSTALL_DIR && \
    curl -sqL "$STEAMCMD_URL" | tar zxvf -"
buildah run $ctr "$STEAMCMD_PATH" +quit

buildah run $ctr mkdir -p $DST_INSTALL_DIR
buildah run $ctr mkdir -p $DST_USER_DATA_DIR

# Deploy DST SteamCMD script
buildah run $ctr sh -c "cat > $DST_INSTALL_DIR/install_dst.steamcmd << 'EOF'
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
force_install_dir ${DST_INSTALL_DIR}
login anonymous
app_update 343050 validate
quit
EOF"
buildah run $ctr sh -c "cat > $DST_INSTALL_DIR/update_dst.steamcmd << 'EOF'
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
force_install_dir ${DST_INSTALL_DIR}
login anonymous
app_update 343050
quit
EOF"
buildah run $ctr "$STEAMCMD_PATH" +runscript $DST_INSTALL_DIR/install_dst.steamcmd
# Move the mods directory to the persistent storage and create a symlink to it in the installation directory, so that mods can be persisted across container restarts and updates
buildah run $ctr mv $DST_INSTALL_DIR/mods $DST_USER_DATA_DIR
buildah run $ctr ln -s $DST_USER_DATA_DIR/mods $DST_INSTALL_DIR/mods
buildah run $ctr mkdir -p $DST_UGC_PATH

# Configure container runtime environment variables
buildah config --env STEAMCMD_PATH=${STEAMCMD_PATH} $ctr
buildah config --env DST_INSTALL_DIR=${DST_INSTALL_DIR} $ctr
buildah config --env DST_USER_DATA_DIR=${DST_USER_DATA_DIR} $ctr
buildah config --env DST_MODS_PATH=${DST_MODS_PATH} $ctr
buildah config --env DST_UGC_PATH=${DST_UGC_PATH} $ctr

# Copy the updated DST server script
buildah copy --chmod=0755 $ctr "$(dirname "$0")/files/update_dst_server.sh" /usr/local/bin/update_dst_server.sh

# Update the entrypoint to use the renamed script
buildah config --cmd "/usr/sbin/init" $ctr

buildah config --volume $DST_USER_DATA_DIR $ctr
buildah config --port "10998-10999/udp" $ctr
buildah config --port "27017-27018/udp" $ctr

# Copy systemd service files
buildah copy $ctr "$(dirname "$0")/files/dst_master.service" /etc/systemd/system/dst_master.service
buildah copy $ctr "$(dirname "$0")/files/dst_caves.service" /etc/systemd/system/dst_caves.service

# Enable the systemd services
buildah run $ctr systemctl enable dst_master.service
buildah run $ctr systemctl enable dst_caves.service

# commit $ctr ${IMAGE_NAME}
commit_and_squash $ctr ${IMAGE_NAME}

# Remove the container after committing the image
buildah rm $ctr
