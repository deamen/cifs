# Create a multi-arch manifest
buildah manifest create nbde-tang-server

# Add both amd64 and arm64 images
buildah manifest add nbde-tang-server nbde-tang-server-amd64
buildah manifest add nbde-tang-server nbde-tang-server-arm64

# Push the multi-arch image (optional)
buildah manifest push --all nbde-tang-server docker://your-dockerhub-user/nbde-tang-server:latest

