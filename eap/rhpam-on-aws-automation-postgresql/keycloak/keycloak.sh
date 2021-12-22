#!/bin/bash

source installer/keycloak.properties
source ../lib/common-functions.sh

# to be able to reuse some common functions, instantiate variables used there
RHPAM_SERVER_IP=$KEYCLOAK_SERVER_IP
RHPAM_SERVER_PORT=$KEYCLOAK_SERVER_PORT
EAP_HOME=$KEYCLOAK_HOME
RHPAM_HOME=$KEYCLOAK_DATA_DIR

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
  copyFile "../lib" "rhpam-functions.sh"

  mkdir -p ./keycloak_tmp
  sed 's@${KEYCLOAK_DATA_DIR}@'$KEYCLOAK_DATA_DIR'@' ./installer/keycloak.service > ./keycloak_tmp/keycloak.service
  copyFolder "./keycloak_tmp"
  rm -rf ./keycloak_tmp
}

function installOnMachine(){
  execute "cd /tmp; ./keycloak.sh"
}

stopServer
copyResources
installOnMachine
