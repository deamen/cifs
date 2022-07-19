# alma9
Folder for building AlmaLinux OS 9 container images

## alma9-base
The alma9-base image is built from AlmaLinux OS 9 repo and is used as base image for alma9-init and rocky-minimal.

Rocky Linux doesn't offer their rootfs tarball for downloading, and the livemeida-creator is not working in conternerized environment yet, so the alma9-base use multi-stage build method.

We pull AlmaLinux OS 9 container image and use dnf --installroot to install packages to a rootfs folder, then copy the rootfs content as the root filesystem in alma9-base image.

## alma9-init
The alma9-init image is for building multi-services containers. 

Use it as a base image, add software then systemctl enable service.

## alma9-minimal
The alma9-minimal image is for building single service container. 
