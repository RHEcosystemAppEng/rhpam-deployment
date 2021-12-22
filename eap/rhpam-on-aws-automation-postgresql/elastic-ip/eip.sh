#!/bin/bash

source $(dirname "$0")/eip.properties
source $(dirname "$0")/../lib/common-functions.sh
source $(dirname "$0")/../lib/rhpam-functions.sh

INSTALL_LOCATION_USE_SUDO=unset
INSTALL_LOCATION_IS_REMOTE=unset
SERVICE_SCRIPT="auto_attach_eip.service"
SERVICE_LAUNCHER="auto_attach_eip.sh"

function initInstaller() {
  headerLog "initInstaller"
  rm $(dirname $0)/installer.log
  log "$(date) Starting installation of EIP attach script on ${RHPAM_SERVER_IP}"

  INSTALL_LOCATION_USE_SUDO=true
  INSTALL_LOCATION_IS_REMOTE=true
  if [ ${INSTALL_TYPE} == 'LOCAL' ]
  then
    INSTALL_LOCATION_USE_SUDO=false
    INSTALL_LOCATION_IS_REMOTE=false
  fi

  log "RHPAM_SERVER_IP=${RHPAM_SERVER_IP}"
  log "SSH_PEM_FILE=${SSH_PEM_FILE}"
  log "SSH_USER_ID=${SSH_USER_ID}"
}

function copyResources(){
  headerLog "copyResources"
  copyFolder "$(dirname "$0")/runtime"

  mkdir -p ./overwrites_tmp
  sed 's@${RHPAM_HOME}@'$RHPAM_HOME'@' ./runtime/auto_attach_eip.service > ./overwrites_tmp/auto_attach_eip.service
  copyFolder "./overwrites_tmp"
  rm -rf ./overwrites_tmp
}

initInstaller
copyResources
installAwsCli
configureAndStartService "${SERVICE_SCRIPT}" "${SERVICE_LAUNCHER}"
