#!/bin/bash

source $(dirname "$0")/installer.properties
source $(dirname "$0")/lib/common-functions.sh

collectionFile=$1

if [ -f "$collectionFile" ]; then
  initInstaller
  echo "Starting execution of Postman collection ${collectionFile}"
  copyFile ${collectionFile}
  log "Installing NodeJS"
  execute "sudo dnf -y module install nodejs/minimal"
  log "Installing Newman CLI"
  execute "sudo npm install -g newman"

  collectionFileName=$(basename $collectionFile)
  log "Running Postman collection /tmp/$collectionFileName"
  execute "newman run /tmp/${collectionFileName}"

  log "Uninstalling Newman CLI"
  execute "sudo npm uninstall -g newman"
  log "Uninstalling NodeJS"
  execute "sudo dnf -y module remove nodejs/minimal"
else
    echo "Cannot find Postman collection file $collectionFile"
    exit 2
fi

