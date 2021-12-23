#!/bin/bash

repoRoot=$(git rev-parse --show-toplevel)
libFolder="${repoRoot}/eap/rhpam-on-aws-automation-postgresql/lib"

source installer.properties
source "${libFolder}/common-functions.sh"
source "${libFolder}/rhpam-functions.sh"

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

SERVICE_SCRIPT="keycloak.service"
SERVICE_LAUNCHER="keycloak-service.sh"

function copyResources(){
  headerLog "copyResources"
  copyFolder "./files"
  copyFile "." "installer.properties"

  mkdir -p ./keycloak_tmp
  sed 's@${KEYCLOAK_DATA_DIR}@'$KEYCLOAK_DATA_DIR'@' ./files/keycloak.service > ./keycloak_tmp/keycloak.service
  copyFolder "./keycloak_tmp"
  rm -rf ./keycloak_tmp
}

function installKeycloak(){
  headerLog "installKeycloak"
  execute "sudo rm -rf ${KEYCLOAK_HOME}; sudo mkdir ${KEYCLOAK_HOME}"
  execute "sudo rm -rf ${KEYCLOAK_DATA_DIR}; sudo mkdir -p ${KEYCLOAK_DATA_DIR}"

  execute "sudo cp /tmp/${KEYCLOAK_INSTALLER} ${KEYCLOAK_HOME}"
  execute "cd ${KEYCLOAK_HOME}"
  execute "sudo tar -xvzf ${KEYCLOAK_INSTALLER} --strip-components=1"
  execute "sudo rm ${KEYCLOAK_INSTALLER}"
  startServer
  execute "sudo ${KEYCLOAK_HOME}/bin/add-user-keycloak.sh -r master -u $KEYCLOAK_ADMIN_USER -p $KEYCLOAK_ADMIN_PWD"
  stopServer
}

stopServer
copyResources
if [[ ${INSTALL_TYPE} == 'REMOTE' ]]; then
  installDependencies
  stopFirewallService
fi
installKeycloak
if [[ ${INSTALL_TYPE} == 'REMOTE' ]]; then
  configureAndStartService "${SERVICE_SCRIPT}" "${SERVICE_LAUNCHER}"
  logService "${SERVICE_SCRIPT}"
else
  startServer
fi