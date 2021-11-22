#!/bin/bash

source deployment.properties

function execute() {
  cmd=$1
  ssh -i ${SSH_PEM_FILE} azureuser@$SMART_ROUTER_SERVER_IP "${cmd}"
}

function copyResources(){
  echo "copyResources"
  scp -i ${SSH_PEM_FILE} ${SSH_PEM_FILE} azureuser@$SMART_ROUTER_SERVER_IP:/tmp
  scp -i ${SSH_PEM_FILE} ./sr/* azureuser@$SMART_ROUTER_SERVER_IP:/tmp
  scp -i ${SSH_PEM_FILE} ./resources/sr/* azureuser@$SMART_ROUTER_SERVER_IP:/tmp
  scp -i ${SSH_PEM_FILE} deployment.properties azureuser@$KIE_SERVER_IP:/tmp
}

function installSmartRouter(){
  echo "installSmartRouter"
  execute "sudo rm -rf ${SMART_ROUTER_HOME}; sudo mkdir ${SMART_ROUTER_HOME}"
  execute "sudo mkdir -p ${SMART_ROUTER_HOME}/repo"
  execute "sudo mv /tmp/rhpam-7.9.0-smart-router.jar ${SMART_ROUTER_HOME}"
}

function configureAndStartServices(){
  echo "configureAndStartServices"
  execute "sudo mkdir -p /opt/custom-config"
  execute "sudo mv /tmp/deployment.properties /opt/custom-config/deployment.properties "
  execute "sudo systemctl stop sr.service;sudo systemctl disable sr.service;sudo rm /etc/systemd/system/sr.service;sudo systemctl daemon-reload;sudo systemctl reset-failed"
  execute "sudo mv /tmp/sr-service.sh /opt/custom-config"
  execute "sudo mv /tmp/sr.service /etc/systemd/system"
  execute "sudo systemctl start sr.service;sudo systemctl enable sr.service"
}

function stopFirewallService(){
  echo "stopFirewallService"
  execute "sudo systemctl stop firewalld;sudo systemctl disable firewalld"
}

function logStartup(){
  execute "sudo journalctl -u sr.service -f"
}

echo "Installing Smart Router to ${SMART_ROUTER_SERVER_IP}"
copyResources
execute "sudo dnf -y install unzip bind-utils java-11-openjdk-devel"
installSmartRouter
configureAndStartServices
stopFirewallService
logStartup
