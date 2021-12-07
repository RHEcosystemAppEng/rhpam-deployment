#!/bin/bash

source business-central.properties

function execute() {
  cmd=$1
  ssh -i ${SSH_PEM_FILE} $SSH_USER_ID@$BUSINESS_CENTRAL_IP "${cmd}"
}

function copyResources(){
  echo "Transfering resources and installations files to remote server "
  scp -i ${SSH_PEM_FILE} ./bc/* $SSH_USER_ID@$BUSINESS_CENTRAL_IP:/tmp
  scp -i ${SSH_PEM_FILE} ${SSH_PEM_FILE} $SSH_USER_ID@$BUSINESS_CENTRAL_IP:/tmp
  
  #Transfer installations required for automation
  # scp -i ${SSH_PEM_FILE} ./binaries*.jar $SSH_USER_ID@$BUSINESS_CENTRAL_IP:/tmp
  # scp -i ${SSH_PEM_FILE} ./binaries/*.zip $SSH_USER_ID@$BUSINESS_CENTRAL_IP:/tmp  
  
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./bc/eap-auto.xml > ./bc/eap-auto-updated.xml
  scp -i ${SSH_PEM_FILE} ./bc/eap-auto-updated.xml $SSH_USER_ID@$BUSINESS_CENTRAL_IP:/tmp/eap-auto.xml
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./bc/bc-auto.xml > bc/bc-auto-updated.xml
  scp -i ${SSH_PEM_FILE} bc/bc-auto-updated.xml $SSH_USER_ID@$BUSINESS_CENTRAL_IP:/tmp/bc-auto.xml
  sed 's@${rhpam.sso.auth.url}@'$SSO_AUTH_URL'@' ./bc/standalone-full.xml | sed 's@${rhpam.sso.token}@'$SSO_BC_SECRET'@' > ./bc/standalone-full-updated.xml
  scp -i ${SSH_PEM_FILE} bc/standalone-full-updated.xml $SSH_USER_ID@$BUSINESS_CENTRAL_IP:/tmp/standalone-full.xml
  sed 's@${MAVEN_REPO_USERNAME}@'$MAVEN_REPO_USERNAME'@g ; s@${MAVEN_REPO_PASSWORD}@'$MAVEN_REPO_PASSWORD'@g' ./bc/settings.xml > bc/settings-updated.xml
  scp -i ${SSH_PEM_FILE} bc/settings-updated.xml $SSH_USER_ID@$BUSINESS_CENTRAL_IP:/tmp/settings.xml

  scp -i ${SSH_PEM_FILE} business-central.properties $SSH_USER_ID@$BUSINESS_CENTRAL_IP:/tmp
}

function installEapAndServer(){
  echo "installEapAndServer"
  execute "sudo rm -rf ${EAP_HOME}; sudo mkdir ${EAP_HOME}"

  execute "cd /tmp; sudo java -jar /tmp/jboss-eap-7.3.0-installer.jar /tmp/eap-auto.xml"
  execute "sudo cp ${EAP_HOME}/standalone/configuration/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml.bak"
  # start jboss cli in disconnected mode, apply patch 7.3.6, and exit from jboss cli shell.
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --command=\"patch apply /tmp/jboss-eap-7.3.6-patch.zip\""

#extract rhsso-adapter files into temp directory;
  execute "cd /tmp; sudo mkdir rh-sso;  sudo unzip rh-sso-7.4.9-eap7-adapter-dist.zip -d ${EAP_HOME}"
  echo "Load the SSO adapter into JBOSS..."
 execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=${EAP_HOME}/bin/adapter-elytron-install-offline.cli -Dserver.config=standalone-full.xml"  
   echo "installing RHPAM..."
 execute "cd /tmp; sudo java -jar rhpam-installer-7.11.1.jar /tmp/bc-auto.xml"
 execute "sudo mv /tmp/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml"
}

function configureBusinessCentral() {
  echo "configureBusinessCentral"
  execute "sudo mkdir -p /opt/custom-config"
  execute "sudo mv /tmp/settings.xml /opt/custom-config"
  # execute "sudo mv ${EAP_HOME}/standalone/configuration/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml.bak"
  # execute "sudo mv /tmp/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml"
  execute "sudo mv /tmp/application-*.properties ${EAP_HOME}/standalone/configuration"
}

function stopFirewallService(){
  echo "stopFirewallService"
  execute "sudo systemctl stop firewalld;sudo systemctl disable firewalld"
}

function configureAndStartServices(){
  echo "configureAndStartServices"
  execute "sudo systemctl stop bc.service;sudo systemctl disable bc.service;sudo rm /etc/systemd/system/bc.service;sudo systemctl daemon-reload;sudo systemctl reset-failed"
  execute "sudo mv /tmp/business-central.properties /opt/custom-config"
  execute "sudo mv /tmp/bc-service.sh /opt/custom-config"
  execute "sudo mv /tmp/bc.service /etc/systemd/system"
  execute "sudo systemctl start bc.service;sudo systemctl enable bc.service"
}

function logStartup(){
  echo "Finish"
  execute "sudo journalctl -u bc.service -f"
}

echo "Installing Business Central to ${BUSINESS_CENTRAL_IP}"
copyResources
execute "sudo dnf -y install unzip bind-utils java-11-openjdk-devel"
installEapAndServer
configureBusinessCentral
configureAndStartServices
stopFirewallService
logStartup
