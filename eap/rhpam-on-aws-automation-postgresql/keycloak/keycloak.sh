#!/bin/bash

source installer/keycloak.properties
source ../lib/common-functions.sh

# to be able to reuse some common functions, instantiate variables used there
RHPAM_SERVER_IP=$KEYCLOAK_SERVER_IP
RHPAM_SERVER_PORT=$KEYCLOAK_SERVER_PORT
EAP_HOME=$KEYCLOAK_HOME

INSTALL_LOCATION_USE_SUDO=false
INSTALL_LOCATION_IS_REMOTE=true
if [ ${INSTALL_TYPE} == 'LOCAL' ]
then
  INSTALL_LOCATION_IS_REMOTE=false
fi

function copyResources(){
  headerLog "copyResources"
  copyFolder "./installer"
  copyFile "../lib" "common-functions.sh"
}

function installOnMachine(){
  execute "cd /tmp; ./keycloak.sh"
}

stopServer
copyResources
installOnMachine
