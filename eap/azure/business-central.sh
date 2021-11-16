function execute() {
  cmd=$1
  ssh -i ${SSH_PEM_FILE} azureuser@$BUSINESS_CENTRAL_IP "${cmd}"
}

function copyResources(){
#  scp -i ${SSH_PEM_FILE} ./resources/* azureuser@$BUSINESS_CENTRAL_IP:/tmp
  scp -i ${SSH_PEM_FILE} ${SSH_PEM_FILE} azureuser@$BUSINESS_CENTRAL_IP:/tmp
  scp -i ${SSH_PEM_FILE} ./bc/* azureuser@$BUSINESS_CENTRAL_IP:/tmp

  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./resources/eap-auto.xml > resources/eap-auto-updated.xml
  scp -i ${SSH_PEM_FILE} resources/eap-auto-updated.xml azureuser@$BUSINESS_CENTRAL_IP:/tmp/eap-auto.xml
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./bc/bc-auto.xml > bc/bc-auto-updated.xml
  scp -i ${SSH_PEM_FILE} bc/bc-auto-updated.xml azureuser@$BUSINESS_CENTRAL_IP:/tmp/bc-auto.xml

  sed 's@${MAVEN_REPO_USERNAME}@'$MAVEN_REPO_USERNAME'@g ; s@${MAVEN_REPO_PASSWORD}@'$MAVEN_REPO_PASSWORD'@g' ./bc/settings.xml > bc/settings-updated.xml
  scp -i ${SSH_PEM_FILE} bc/settings-updated.xml azureuser@$BUSINESS_CENTRAL_IP:/tmp/settings.xml

  scp -i ${SSH_PEM_FILE} deployment.properties azureuser@$BUSINESS_CENTRAL_IP:/tmp
}

function installEapAndServer(){
  echo "installEapAndServer"
  execute "sudo rm -rf ${EAP_HOME}; sudo mkdir ${EAP_HOME}"
  execute "cd /tmp; sudo java -jar /tmp/jboss-eap-7.3.0-installer.jar /tmp/eap-auto.xml"
  execute "cd /tmp; sudo java -jar rhpam-installer-7.9.0.zip /tmp/bc-auto.xml"
}

function configureBusinessCentral() {
  echo "configureBusinessCentral"
  execute "sudo mkdir -p /opt/custom-config"
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
  execute "sudo systemctl stop bc.service;sudo systemctl disable bc.service;sudo rm /etc/systemd/system/bc.service;sudo systemctl daemon-reload;sudo systemctl reset-failed"
  execute "sudo mv /tmp/deployment.properties /opt/custom-config"
  execute "sudo mv /tmp/bc-service.sh /opt/custom-config"
  execute "sudo mv /tmp/bc.service /etc/systemd/system"
  execute "sudo systemctl start bc.service;sudo systemctl enable bc.service"
}

function logStartup(){
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