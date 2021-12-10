#!/bin/bash

function execute() {
  cmd=$1
  echo "=== $cmd ==="
  ssh -i ${SSH_PEM_FILE} ${SSH_USER_ID}@$RHPAM_SERVER_IP "${cmd}"
}

function copyFolder() {
  echo "copyFolder $1"
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
  until $(curl --output /dev/null --silent --head --fail http://${RHPAM_SERVER_IP}:8080); do
      printf '.'
      sleep 5
  done
  echo "$(date) Server is up"
}

function startServer(){
  echo "startServer $LAUNCHER"
  execute "cd /tmp; sh -c 'sudo /tmp/${LAUNCHER} > /dev/null 2>&1 &'"
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