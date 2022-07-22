# alpine
Folder for building ALpine Linux container images

## alpine-base
The alpine-base image is built from ALpine Linux "MINI ROOT FILESYSTEM" from https://alpinelinux.org/downloads/

## alpine-init
The alpine-init image has openrc installed, use it as a base image. Add services and use openrc to start them.

```ENTRYPOINT ["sh","-c", "rc-status; rc-service sshd start; crond -f"]```

Reference: https://github.com/gliderlabs/docker-alpine/issues/437#issuecomment-667456518

It might be better to use RedHat based container image to build multi-service container, as it is supported. While docker and mobby are against this kind of use.
## alpine-minimal
The alpine-minimal image is for building single service container. 
