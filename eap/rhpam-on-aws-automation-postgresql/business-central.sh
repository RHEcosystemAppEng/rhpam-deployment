#!/bin/bash

source $(dirname "$0")/business-central.properties
source $(dirname "$0")/lib/common-functions.sh
source $(dirname "$0")/lib/eap-functions.sh
source $(dirname "$0")/lib/rhpam-functions.sh

LAUNCHER=bc-service.sh

function copyResources(){
  echo "copyResources "
  copyFolder "./installer/jboss-eap"
  copyFolder "./installer/rhpam"
  copyFolder "./installer/business-central"
  copyFolder "./runtime/business-central"

  mkdir -p ./tmp_installer
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/jboss-eap/eap-auto.xml > ./tmp_installer/eap-auto.xml
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/business-central/bc-auto.xml > ./tmp_installer/bc-auto.xml
  copyFolder "./tmp_installer"
  rm -rf ./tmp_installer
  execute "echo \"\" >> /tmp/runtime.properties"
  execute "echo \"EAP_HOME=${EAP_HOME}\" >> /tmp/runtime.properties"
}

function configureKieServer() {
  echo "configureKieServer"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/rhpam-kieserver.cli"
}

echo "Installing Business Central to ${BUSINESS_CENTRAL_IP}"
copyResources
installDependencies
stopFirewallService
installEap
installSsoAdapter
installRhpam "bc-auto.xml"
configureSso
#startServer
configureMavenRepository
configureKieServer
#stopServer

configureAndStartService "bc.service" "bc-service.sh"
logService "bc.service"
