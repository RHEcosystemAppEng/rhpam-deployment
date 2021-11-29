#!/bin/bash

install_type=$1

source deployment.properties

function execute() {
  cmd=$1
  ssh -i ${SSH_PEM_FILE} azureuser@$KIE_SERVER_IP "${cmd}"
}

function copyResources(){
  scp -i ${SSH_PEM_FILE} ./resources/ks/* azureuser@$KIE_SERVER_IP:/tmp
  scp -i ${SSH_PEM_FILE} ${SSH_PEM_FILE} azureuser@$KIE_SERVER_IP:/tmp
  scp -i ${SSH_PEM_FILE} ./ks/* azureuser@$KIE_SERVER_IP:/tmp

  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./resources/ks/eap-auto.xml > resources/ks/eap-auto-updated.xml
  scp -i ${SSH_PEM_FILE} resources/ks/eap-auto-updated.xml azureuser@$KIE_SERVER_IP:/tmp/eap-auto.xml
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./ks/ks-auto.xml > ks/ks-auto-updated.xml
  scp -i ${SSH_PEM_FILE} ks/ks-auto-updated.xml azureuser@$KIE_SERVER_IP:/tmp/ks-auto.xml

  sed 's@${MAVEN_REPO_USERNAME}@'$MAVEN_REPO_USERNAME'@g ; s@${MAVEN_REPO_PASSWORD}@'$MAVEN_REPO_PASSWORD'@g ; s@${MAVEN_REPO_URL}@'$MAVEN_REPO_URL'@' ./ks/settings.xml > ks/settings-updated.xml
  scp -i ${SSH_PEM_FILE} ks/settings-updated.xml azureuser@$KIE_SERVER_IP:/tmp/settings.xml

  scp -i ${SSH_PEM_FILE} deployment.properties azureuser@$KIE_SERVER_IP:/tmp/deployment.properties
  if [ "$install_type" == UNMANAGED_WITH_SMARTROUTER ]
  then
    scp -i ${SSH_PEM_FILE} ./ks_unmgd_with_sr/* azureuser@$KIE_SERVER_IP:/tmp
  else
    echo 'default install - no override needed'
  fi
}

function installEapAndServer(){
  echo "installEapAndServer"
  execute "sudo rm -rf ${EAP_HOME}; sudo mkdir ${EAP_HOME}"
  execute "cd /tmp; sudo java -jar /tmp/jboss-eap-7.3.0-installer.jar /tmp/eap-auto.xml"
  execute "cd /tmp; sudo java -jar rhpam-installer-7.9.0.jar /tmp/ks-auto.xml"
}

function configureDS(){
  echo "configureDS"
  execute "cd /tmp;wget https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-java-8.0.22.zip"
  execute "cd /tmp;unzip -o mysql-connector-java-8.0.22.zip"
  execute "sudo mkdir -p ${EAP_HOME}/modules/system/layers/base/com/mysql/main"
  execute "sudo cp /tmp/mysql-connector-java-8.0.22/mysql-connector-java-8.0.22.jar ${EAP_HOME}/modules/system/layers/base/com/mysql/main"
  execute "sudo mv /tmp/module.xml ${EAP_HOME}/modules/system/layers/base/com/mysql/main"
}

function configureKieServer() {
  echo "configureKieServer"
  execute "sudo rm -rf /opt/custom-config; sudo mkdir -p /opt/custom-config"
  execute "sudo mv /tmp/settings.xml /opt/custom-config"
  execute "sudo mv ${EAP_HOME}/standalone/configuration/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml.bak"
  execute "sudo mv /tmp/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml"
  execute "sudo mv /tmp/application-*.properties ${EAP_HOME}/standalone/configuration"
}

function stopFirewallService(){
  echo "stopFirewallService"
  execute "sudo systemctl stop firewalld;sudo systemctl disable firewalld"
}

function configureAndStartServices(){
  echo "configureAndStartServices"
  execute "sudo systemctl stop ks.service;sudo systemctl disable ks.service;sudo rm /etc/systemd/system/ks.service;sudo systemctl daemon-reload;sudo systemctl reset-failed"
  execute "sudo mv /tmp/deployment.properties /opt/custom-config"
  execute "sudo mv /tmp/ks-service.sh /opt/custom-config"
  execute "sudo mv /tmp/ks.service /etc/systemd/system"
  execute "sudo systemctl start ks.service;sudo systemctl enable ks.service"
}

function addKieServerContainers(){
   echo "addKieServerContainers - need to wait for kie server to have started up - sleep 100 seconds"
   sleep 100
   echo "trying to add container now"
   execute "sudo mv /tmp/create-container.xml /opt/custom-config"
   execute "cd /opt/custom-config; curl -v -X POST -H 'Content-type: application/xml' -H 'X-KIE-Content-Type: xstream' -d @create-container.xml \
   -u rhpamAdmin:redhat123# http://${KIE_SERVER_IP}:${KIE_SERVER_PORT}/kie-server/services/rest/server/config/"
   execute "sudo systemctl restart ks.service"
}

function logStartup(){
  execute "sudo journalctl -u ks.service -f"
}

echo "Installing KIE Server to ${KIE_SERVER_IP}"
copyResources
execute "sudo dnf -y install unzip bind-utils java-11-openjdk-devel"
installEapAndServer
configureDS
configureKieServer
configureAndStartServices
if [ "$install_type" == UNMANAGED_WITH_SMARTROUTER ]
then
  addKieServerContainers
else
  echo 'default install - no immutable kie server'
fi
stopFirewallService
logStartup
