# Keycloak installation
## Installation
- configure the properties in `./installer/keycloak.properties`  
how to decide on INSTALL_TYPE 
  - LOCAL: when installing on laptop where certain infrastructure is assumed to exist
  - REMOTE_PARTIAL: if the application is already installed and only needs to be configured
  - REMOTE_FULL: if the remote machine only contains a basic RHEL OS
- Run script `./keycloak.sh`
