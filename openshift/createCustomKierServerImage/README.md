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
The following reference instructions configure Vagrant and install a Podman server, then connect it to the Podman 
client used to build the custom image and push it on the quay.io registry:
```sh
cd <ROOT FOLDER OF temenos-rhpam7>/01-createCustomKierServerImage
export VAGRANT_CWD=$PWD
export CONTAINER_HOST=ssh://vagrant@127.0.0.1:2222/run/podman/podman.sock
export CONTAINER_SSHKEY=$PWD/.vagrant/machines/default/virtualbox/private_key

vagrant up
podman system connection add fedora33 ssh://vagrant@127.0.0.1:2222

podman login -u='11009103|dmartino' \
-p=eyJhbGciOiJSUzUxMiJ9.eyJzdWIiOiJjNjEwOWJjZjcyNjU0ODQzODFiNzUzMzhjNzJmZGExNiJ9.p0KBU_Mn8S5hxQcgSqIj1mac6_c5oc1YY9owoIPzm0eyICdLMej5Jt8BoKFYpn1Pn4alqjQZTzrK3RSg9EM1SHDpLdqS70yEgMObGt62mFNsapRfw6h1F7V7JkS-J9L23jweKX6pfs4L0zgQhsckBVNj7UU-DVnDkHBE3C7-I7bPR92MAy53Po4eon9pV_cj0iWOzGrj7nCVNiQRDFj_AceHGz-A9EgbCH4Itwfa-02zQz7q2I3tzbIAkhGC9nlZq_rtJG96ULTc8wVuNDXznX81q1MpuLTjwpleASF8PEuFILpZlPpfqX-fsO27_EFOkzGzI_EuCs1xpqfgj7wvIWRD3mef7jWQl3mDIUqC5h6xE6b5ofTBj8MMX3-gDTHUA6fJ1JUdmWrkygh8MqN1gAxfHJ7L3i1nfFVEKntkRr_TFLmxzbAjXuB0TuTi9H34BwSDrnj0FAoLSIjOMvjcVKFRKmj_0VpqIesQW61zJssQZRqaMaYEJNXjsUu3QMBaNPgh3ukiJ-t-rxmefCF8c5MSMtpbR_FOrpLmIFq5ft3LifUdfbTQc4tOwZ6KlJLM2geOQxZT2R3mEmqkKWEnaIQXn_w6W7-m6x1E1HDkUkdhYM5VqlwRMm4VPl9uJXoRuB4d7YYGjWEzUZF7nUMxTQzE7OOJ7DypefIPHc8mVpI registry.redhat.io
podman build -t quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom-mssql:7.9.0 .
podman login quay.io
podman push quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom-mssql:7.9.0
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
* Install git from [Git Bash](https://gitforwindows.org/) and clone the repository as 
`git clone https://github.com/RHEcosystemAppEng/temenos-infinity-cib.git`
* Install podman client from [Podman Installation Instructions](https://podman.io/getting-started/installation.html)
* Install VirtualBox from [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* Install Vagrant from [Download Vagrant](https://www.vagrantup.com/downloads)




