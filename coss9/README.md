# coss9
Folder for building CentOS Stream 9 container images

## coss9:base
The coss9:base image is the base image built from CentOS Stream 9 cloud image tarball https://cloud.centos.org/centos/9-stream/x86_64/images/ .

## coss9-init
The coss9-init image is for building multi-services containers. 
Use it as a base image, add software then systemctl enable service.