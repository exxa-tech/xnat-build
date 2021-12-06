# XNAT build

```console
# Download pre-requisite files
$ make

# Build all images
$ packer build xnat-web.pkr.hcl

# Build an individual image
$ packer build -only docker.xnat17 xnat-web.pkr.hcl

# Build all docker images
$ packer build -only docker.* xnat-web.pkr.hcl

# Push to Docker Hub repo
docker push archetype/xnat-web:1.8.2.2
```

Reference:
* https://bitbucket.org/xnatdev/container-service/downloads/
