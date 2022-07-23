# debian
Folder for building Debian Linux container images

## debian-base
The debian-base image is built from Debian Linux repo and is used as base image for debian-init and debian-minimal.

Debian Linux doesn't offer their rootfs tarball for downloading, so the debian-base use multi-stage build method and debootstrap.

We pull Debian Linux container image and use debootstrap to install packages to a rootfs folder, then copy the rootfs content as the root filesystem in debian-base image.

## debian-init
The debian-init image is for building multi-services containers. 

Use it as a base image, add software then systemctl enable service.

## debian-minimal
The debian-init image is for building single service container. 
