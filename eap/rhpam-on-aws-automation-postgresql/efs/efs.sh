#!/bin/bash

source $(dirname "$0")/efs.properties
source $(dirname "$0")/../lib/common-functions.sh

function initInstaller() {
  headerLog "initInstaller"
  rm $(dirname $0)/installer.log
  log "$(date) Starting installation of ${RHPAM_SERVER} on ${RHPAM_SERVER_IP}"
  log "RHPAM_SERVER_IP=${RHPAM_SERVER_IP}"
  log "SSH_PEM_FILE=${SSH_PEM_FILE}"
  log "SSH_USER_ID=${SSH_USER_ID}"
  log "RHPAM_EFS_HOME=${RHPAM_EFS_HOME}"
  log "EFS_IP=${EFS_IP}"
  log "EFS_ROOT_PATH=${EFS_ROOT_PATH}"
  log "EFS_OPTIONS=${EFS_OPTIONS}"
}

function copyResources(){
  headerLog "copyResources"
  copyFolder "$(dirname "$0")/installer"
}

function mountEfsFileSystem(){
  headerLog "mountEfsFileSystem"
  execute "/tmp/efs.sh ${RHPAM_EFS_HOME} ${EFS_IP} ${EFS_ROOT_PATH} '${EFS_OPTIONS}'"
}

INSTALL_LOCATION_USE_SUDO=true
INSTALL_LOCATION_IS_REMOTE=true
DRY_RUN_ONLY=no
initInstaller
copyResources
mountEfsFileSystem
