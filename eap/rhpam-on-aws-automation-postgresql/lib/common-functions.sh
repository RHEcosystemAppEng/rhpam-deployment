#!/bin/bash

# the following two flags are used to be able to reuse "common-functions.sh" for both remote and local installations,
# they should be set in the script or properties file used for the installation
# INSTALL_LOCATION_IS_REMOTE: true assumes machine running installation is different from machine being installed => remote access mechanisms needed
# INSTALL_LOCATION_USE_SUDO: false removes any sudo directive from a command send to the "execute" function

function log() {
  echo $1
  echo "$1" >> $(dirname $0)/installer.log
}

function execute() {
  cmd=$1

  if [ $INSTALL_LOCATION_USE_SUDO == false ]
  then
     cmd=${cmd//sudo /""}
  fi
  if [[ "${DRY_RUN_ONLY}" != "yes" ]]; then
    if [ $INSTALL_LOCATION_IS_REMOTE == true ]
    then
      echo "=== remote install: $cmd ==="
      ssh -i ${SSH_PEM_FILE} ${SSH_USER_ID}@$RHPAM_SERVER_IP "${cmd}"
    else
      echo "=== local install: $cmd ==="
      eval $cmd
    fi
  else
    log "${cmd}"
  fi
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
      if ssh -i ${SSH_PEM_FILE} ${SSH_USER_ID}@${RHPAM_SERVER_IP} "test -e /tmp/${f}"; then
        echo "Skipping ${f}"
      else
        scp -i ${SSH_PEM_FILE} ${folder}/${f} ${SSH_USER_ID}@${RHPAM_SERVER_IP}:/tmp
      fi
    else
        scp -i ${SSH_PEM_FILE} ${folder}/${f} ${SSH_USER_ID}@${RHPAM_SERVER_IP}:/tmp
    fi
  else
    echo "copyFile local: ${f}"
      cp ${folder}/${f} /tmp
  fi
}

function stopFirewallService(){
  echo "******************** stopFirewallService *******************"
  execute "sudo systemctl stop firewalld;sudo systemctl disable firewalld"
}

function installDependencies(){
  echo "******************** installDependencies ********************"
  execute "sudo dnf -y install unzip bind-utils java-11-openjdk-devel"
}

function waitForServer() {
  echo "******************** $(date) waitForServer http://${RHPAM_SERVER_IP}:${RHPAM_SERVER_PORT} ********************"
  if [[ "${DRY_RUN_ONLY}" != "yes" ]]; then
    until $(curl --output /dev/null --silent --head --fail http://${RHPAM_SERVER_IP}:${RHPAM_SERVER_PORT}); do
        printf '.'
        sleep 5
  done
  fi
  echo "$(date) Server is up"
}

function startServer(){
  echo "******************** startServer $SERVICE_LAUNCHER ********************"
  execute "cd /tmp; sh -c 'sudo /tmp/${SERVICE_LAUNCHER} > /dev/null 2>&1 &'"
  waitForServer
}

function stopServer(){
  echo "******************** stopServer ********************"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --connect --timeout=60000 --command=shutdown"
}

function logService(){
  echo "******************** logService $1 ********************"
  service=$1
  execute "sudo journalctl -u ${service} -f"
}

function getPortWithOffset(){
  echo $((8080+$1))
}