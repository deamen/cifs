# alma8
Folder for building AlmaLinux OS 8 container images

## alma8-base
The alma8-base image is built from AlmaLinux OS 8 repo and is used as base image for alma8-init and rocky-minimal.

Rocky Linux doesn't offer their rootfs tarball for downloading, and the livemeida-creator is not working in conternerized environment yet, so the alma8-base use multi-stage build method.

We pull AlmaLinux OS 8 container image and use dnf --installroot to install packages to a rootfs folder, then copy the rootfs content as the root filesystem in alma8-base image.

## alma8-init
The alma8-init image is for building multi-services containers. 

Use it as a base image, add software then systemctl enable service.

## alma8-minimal
The alma8-minimal image is for building single service container. 
