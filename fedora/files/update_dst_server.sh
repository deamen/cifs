#!/bin/bash
set -e

# The persistent storage path is generated like this:
# ${DST_USER_DATA_DIR}/${conf_dir}/${cluster}/
# Shard configuration files are in ${DST_USER_DATA_DIR}/${conf_dir}/${cluster}/Master and ${DST_USER_DATA_DIR}/${conf_dir}/${cluster}/Caves
# Check ${DST_USER_DATA_DIR}/Cluster_1/cluster_token.txt exits and is not empty, if not, exit with error message
if [ ! -s "${DST_USER_DATA_DIR}/Cluster_1/cluster_token.txt" ]; then
    echo "Error: ${DST_USER_DATA_DIR}/Cluster_1/cluster_token.txt does not exist or is empty. Please make sure to create the cluster token file with the correct token value before running the DST server."
    exit 1
fi

echo "Updating DST server using SteamCMD..."
"$STEAMCMD_PATH" +runscript $DST_INSTALL_DIR/update_dst.steamcmd

echo "Updating DST server mods..."
# Use printf to send a single “Enter” at the end of the command shut down the program, 
# otherwise it hangs at Shutting down and wait for user input indefinitely
printf '\n' | ${DST_INSTALL_DIR}/bin64/dontstarve_dedicated_server_nullrenderer_x64 -persistent_storage_root "${DST_USER_DATA_DIR}" -conf_dir / -ugc_directory "${DST_UGC_PATH}" -cluster Cluster_1 -only_update_server_mods -shard Master
