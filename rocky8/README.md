# rocky8
Folder for building Rocky Linux 8 container images

## rocky8-base
The rocky8-base image is the base image built from Rocky Linux 8 repo, used as base image for rocky8-init and rocky-minimal.

Rocky Linux doesn't offer their rootfs tarball for downloading, and the livemeida-creator is not working in conternerized environment yet, so the rocky8-base use multi-stage build method.

We pull Rocky Linux 8 container and use dnf --installroot to install packages to a rootfs folder, then copy the rootfs content as the root filesystem in rocky8-base image.

## rocky8-init
The rocky8-init image is for building multi-services containers. 
Use it as a base image, add software then systemctl enable service.

## rocky8-minimal
The rocky8-init image is for building single service container. 
