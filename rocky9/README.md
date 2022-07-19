# rocky9
Folder for building Rocky Linux 9 container images

## rocky9-base
The rocky9-base image is built from Rocky Linux 9 repo and is used as base image for rocky9-init and rocky-minimal.

Rocky Linux doesn't offer their rootfs tarball for downloading, and the livemeida-creator is not working in conternerized environment yet, so the rocky9-base use multi-stage build method.

We pull Rocky Linux 9 container image and use dnf --installroot to install packages to a rootfs folder, then copy the rootfs content as the root filesystem in rocky9-base image.

## rocky9-init
The rocky9-init image is for building multi-services containers. 

Use it as a base image, add software then systemctl enable service.

## rocky9-minimal
The rocky9-init image is for building single service container. 
