# Table of Contents
* [Creating a custom KIE Server image with an additional JAR file](#creating-a-custom-kie-server-image-with-an-additional-jar-file)
  * [Download custom code](#download-custom-code)
  * [Building container image](#building-container-image)
    * [The Dockerfile](#the-dockerfile)
    * [Building with Podman on Linux](#building-with-podman-on-linux)
    * [Podman on MacOS](#podman-on-macos)
      * [Configuring Podman on MacOS](#configuring-podman-on-macos)
      * [Building with Podman on MacOS](#building-with-podman-on-macos)
    * [Podman on Windows OS](podman-on-windows-os)
    
# Creating a custom KIE Server image with an additional JAR file

## Download custom code
Download from the _Shared artifacts folder_ 
the file `Origination_PAM_NNN.zip` and put it under <01-createCustomKierServerImage folder of temenos-rhpam7>, then:
```shell
cd <ROOT FOLDER OF temenos-rhpam7>/01-createCustomKierServerImage
unzip Origination_PAM_NNN.zip
```

## Building container image
### The Dockerfile
This repositoru contains a template of the [Dockerfile](./Dockerfile) for illustration purpose only. Have a look at this file and customize
it to match your actual requirements.

### Building with Podman on Linux
```sh
cd <ROOT FOLDER OF temenos-rhpam7>/01-createCustomKierServerImage
podman build . -t quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.11.0-4
podman login quay.io
podman push quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.11.0-4
```
You can replace `podman login quay.io` with ad-hoc login command generated from _User Settings_ page in [Quay](https://quay.io/)

### Podman on MacOS
#### Configuring Podman on MacOS
Requirements:
* [Vagrant](https://www.vagrantup.com/downloads)
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* Install Podman client as `brew install podman`

#### Building with Podman on MacOS
Configure Vagrant to use the current configuration:
```sh
cd <ROOT FOLDER OF temenos-rhpam7>/01-createCustomKierServerImage
export VAGRANT_CWD=$PWD
export CONTAINER_HOST=ssh://vagrant@127.0.0.1:2222/run/podman/podman.sock
export CONTAINER_SSHKEY=$PWD/.vagrant/machines/default/virtualbox/private_key
```

Vagrant configuration takes care to:
* Copy the required Dockerfile and generated JAR on the running Fedora image
* Install podman  
* Build the container image with Podman 
* Deploy it on the quay.io registry
```sh
vagrant up
```
*Note*: changes are required to the given [Vagrantfile](./Vagrantfile) to setup the proper token for both the
_registry.redhat.io_ and the _quay.io_ container registries (look for two occurrences of
"podman login" command invocation).
*Note*: it may take some time before the podman login is actually effective, if an error happens, try a second 
execution with `vagrant provision`

You can verify the result by accessing the Vagrant box via SSH (use vagrant/vagrant as username and password):
```sh
vagrant ssh default
sudo podman images
```
Once you verify that the image was published on Quay registry, you can shutdown the Virtual Box image with `vagrant halt` 

### Podman on Windows OS
**Work in progress**
