# Installation
Allows installing Keycloak on a remote machine via ssh or locally.
1. Fill in the [installer.properties](./installation/installer.properties)
2. Place the file defined as `KEYCLOAK_INSTALLER` in the `./installation/files` folder
3. Run `./installation/installer.sh`

# Configuration
Configures an existing keycloak installation with realms, clients, users and roles
1. Fill in the [config.properties](./configuration/config.properties)
2. Copy folder `./configuration` to the keycloak machine
3. Run `./configuration/config.sh` on the keycloak machine
