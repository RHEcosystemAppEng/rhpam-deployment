#!/bin/bash

function log() {
  echo $1
  echo "$1" >> $(dirname $0)/installer.log
}

function execute() {
  cmd=$1
  echo "=== $cmd ==="
  if [[ "${DRY_RUN_ONLY}" != "yes" ]]; then
    ssh -i ${SSH_PEM_FILE} ${SSH_USER_ID}@$RHPAM_SERVER_IP "${cmd}"
  else
    log "${cmd}"
  fi
}

function copyFile() {
  echo "copyFolder $1"
  f=$1
  if [[ "${DRY_RUN_ONLY}" != "yes" ]]; then
    scp -i ${SSH_PEM_FILE} ${f} ${SSH_USER_ID}@${RHPAM_SERVER_IP}:/tmp
  fi
}

function copyFolder() {
  echo "copyFolder $1"
  if [[ "${DRY_RUN_ONLY}" != "yes" ]]; then
    folder=$1
    for f in $(ls ${folder})
    do
      if [[ $f == *.jar  || $f == *.zip ]]; then
        if ssh -i ${SSH_PEM_FILE} ${SSH_USER_ID}@${RHPAM_SERVER_IP} "test -e /tmp/${f}"; then
          echo "Skipping ${f}"
        else
          scp -i ${SSH_PEM_FILE} ${folder}/${f} ${SSH_USER_ID}@${RHPAM_SERVER_IP}:/tmp
        fi
      else
        scp -i ${SSH_PEM_FILE} ${folder}/${f} ${SSH_USER_ID}@${RHPAM_SERVER_IP}:/tmp
      fi
    done
  fi
}

function stopFirewallService(){
  echo "stopFirewallService"
  execute "sudo systemctl stop firewalld;sudo systemctl disable firewalld"
}

function installDependencies(){
  echo "installDependencies"
  execute "sudo dnf -y install unzip bind-utils java-11-openjdk-devel"
}

function waitForServer() {
  echo "$(date) waitForServer http://${RHPAM_SERVER_IP}:8080"
  if [[ "${DRY_RUN_ONLY}" != "yes" ]]; then
    until $(curl --output /dev/null --silent --head --fail http://${RHPAM_SERVER_IP}:8080); do
        printf '.'
        sleep 5
    done
  fi
  echo "$(date) Server is up"
}

function startServer(){
  echo "startServer ${SERVICE_LAUNCHER}"
  execute "cd /tmp; sh -c 'sudo /tmp/${SERVICE_LAUNCHER} > /dev/null 2>&1 &'"
  waitForServer
}

function stopServer(){
  echo "stopServer"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --connect --timeout=60000 --command=shutdown"
}

function logService(){
  echo "logService $1"
  service=$1
  execute "sudo journalctl -u ${service} -f"
}