#!/bin/bash

# the following two flags are used to be able to reuse "common-functions.sh" for both remote and local installations,
# they should be set in the script or properties file used for the installation
# INSTALL_LOCATION_IS_REMOTE: true assumes machine running installation is different from machine being installed => remote access mechanisms needed
# INSTALL_LOCATION_USE_SUDO: false removes any sudo directive from a command send to the "execute" function
SERVICE_SCRIPT=unset
SERVICE_LAUNCHER=unset
RHPAM_INSTALLER_XML=unset
INSTALL_LOCATION_USE_SUDO=unset
INSTALL_LOCATION_IS_REMOTE=unset

function initInstaller() {
  headerLog "initInstaller"
  rm $(dirname $0)/installer.log
  log "$(date) Starting installation of ${RHPAM_SERVER} on ${RHPAM_SERVER_IP}"
  log "DRY_RUN_ONLY=${DRY_RUN_ONLY}"
  log "SSH_PEM_FILE=${SSH_PEM_FILE}"
  log "SSH_USER_ID=${SSH_USER_ID}"
  log "RHPAM_SERVER_IP=${RHPAM_SERVER_IP}"
  log "RHPAM_SERVER_PORT=${RHPAM_SERVER_PORT}"
  log "RHPAM_SERVER=${RHPAM_SERVER}"
  log "KIE_SERVER_TYPE=${KIE_SERVER_TYPE}"
  log "EAP_HOME=${EAP_HOME}"
  log "RHPAM_HOME=${RHPAM_HOME}"
  log "RHPAM_PROPS_DIR=${RHPAM_PROPS_DIR}"
  log "GIT_HOME=${GIT_HOME}"

  INSTALL_LOCATION_USE_SUDO=true
  INSTALL_LOCATION_IS_REMOTE=true
  if [ ${INSTALL_TYPE} == 'LOCAL' ]
  then
    INSTALL_LOCATION_USE_SUDO=false
    INSTALL_LOCATION_IS_REMOTE=false
  fi
  if [[ $(isKieServer) ]]; then
    SERVICE_SCRIPT="ks.service"
    SERVICE_LAUNCHER="ks-service.sh"
    RHPAM_INSTALLER_XML="ks-auto.xml"
  else
    SERVICE_SCRIPT="bc.service"
    SERVICE_LAUNCHER="bc-service.sh"
    RHPAM_INSTALLER_XML="bc-auto.xml"
  fi

  log "INSTALL_LOCATION_USE_SUDO=${INSTALL_LOCATION_USE_SUDO}"
  log "INSTALL_LOCATION_IS_REMOTE=${INSTALL_LOCATION_IS_REMOTE}"
  log "SERVICE_SCRIPT=${SERVICE_SCRIPT}"
  log "SERVICE_LAUNCHER=${SERVICE_LAUNCHER}"
  log "RHPAM_INSTALLER_XML=${RHPAM_INSTALLER_XML}"
}

function log() {
  echo $1
  echo "$1" >> $(dirname $0)/installer.log
}
function headerLog() {
  echo "******************* $1 ********************"
  echo "******************* $1 ********************" >> $(dirname $0)/installer.log
}

function execute() {
  cmd=$1
  isLog="yes"
  if [ $2 ]; then isLog="no"; fi

  if [ $INSTALL_LOCATION_USE_SUDO == false ]
  then
     cmd=${cmd//sudo /""}
  fi
  if [[ "${DRY_RUN_ONLY}" != "yes" ]]; then
    if [ $isLog == "yes" ]; then
      echo "=== $cmd ==="
    fi
    if [ $INSTALL_LOCATION_IS_REMOTE == true ]
    then
      ssh -i ${SSH_PEM_FILE} -p ${SSH_PORT} ${SSH_USER_ID}@${RHPAM_SERVER_IP} "${cmd}"
    else
      eval $cmd
    fi
  fi
  log "${cmd}"
}

function copyFolder() {
  folder=$1

  if [[ "${DRY_RUN_ONLY}" != "yes" ]]; then
    if [ $INSTALL_LOCATION_IS_REMOTE == true ]
    then
      echo "copyFolder remote: ${folder}"
      for f in $(ls ${folder})
      do
        copyFile ${folder} ${f}
      done
    else
      echo "copyFolder local: ${folder}"
      for f in $(ls ${folder})
      do
        copyFile ${folder} ${f}
      done
    fi
  fi
}

function copyFile() {
  folder=$1
  f=$2

  if [ $INSTALL_LOCATION_IS_REMOTE == true ]
  then
    echo "copyFile remote: ${f}"
    if [[ $f == *.jar  || $f == *.zip || $f == *.tar.gz ]]; then
      if ssh -i ${SSH_PEM_FILE} -p ${SSH_PORT} ${SSH_USER_ID}@${RHPAM_SERVER_IP} "test -e /tmp/${f}"; then
        echo "Skipping ${f}"
      else
        scp -i ${SSH_PEM_FILE} -P ${SSH_PORT} ${folder}/${f} ${SSH_USER_ID}@${RHPAM_SERVER_IP}:/tmp
      fi
    else
        scp -i ${SSH_PEM_FILE} -P ${SSH_PORT} ${folder}/${f} ${SSH_USER_ID}@${RHPAM_SERVER_IP}:/tmp
    fi
  else
    echo "copyFile local: ${f}"
      cp ${folder}/${f} /tmp
  fi
}

function stopFirewallService(){
  headerLog "stopFirewallService"
  execute "sudo systemctl stop firewalld;sudo systemctl disable firewalld"
}

function installDependencies(){
  isKieServer=$1
  headerLog "installDependencies with isKieServer=$isKieServer"
  execute "sudo dnf -y install unzip bind-utils java-11-openjdk-devel"
  if [ $isKieServer ]; then
    headerLog "installDependencies for kie server"
    execute "sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
    execute "sudo dnf -y update"
    execute "sudo dnf -y install jq"
  fi
}

function waitForServer() {
  headerLog "$(date) waitForServer http://${RHPAM_SERVER_IP}:${RHPAM_SERVER_PORT}"
  if [[ "${DRY_RUN_ONLY}" != "yes" ]]; then
    until $(curl --output /dev/null --silent --head --fail http://${RHPAM_SERVER_IP}:${RHPAM_SERVER_PORT}); do
        printf '.'
        sleep 5
  done
  fi
  echo "$(date) Server is up"
}

function startServer(){
  headerLog "startServer $SERVICE_LAUNCHER"
  execute "cd /tmp; sh -c 'sudo /tmp/${SERVICE_LAUNCHER} > /dev/null 2>&1 &'"
  waitForServer
}

function stopServer(){
  headerLog "stopServer"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --connect --timeout=60000 --command=shutdown"
}

function logService(){
  headerLog "logService $1"
  service=$1
  if [[ ${INSTALL_TYPE} == 'LOCAL' ]]; then
    execute "sudo tail -f ${EAP_HOME}/standalone/log/server.log"
  else
    execute "sudo journalctl -u ${service} -f"
  fi
}

#function getPortWithOffset(){
#  echo $((8080+$1))
#}

function installAwsCli(){
  headerLog "installAwsCli"
  execute "cd /tmp; curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip"
  execute "cd /tmp; unzip awscliv2.zip"
  execute "cd /tmp; sudo ./aws/install"
  execute "cd /tmp; rm -r ./aws"
  execute "cd /tmp; rm awscliv2.zip"
}