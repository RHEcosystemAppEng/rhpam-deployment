#!/bin/bash

source $(dirname "$0")/kie-server.properties
source $(dirname "$0")/lib/common-functions.sh
source $(dirname "$0")/lib/eap-functions.sh
source $(dirname "$0")/lib/rhpam-functions.sh

LAUNCHER=ks-service.sh

function copyResources(){
  echo "copyResources"
  copyFolder "./installer/jboss-eap"
  copyFolder "./installer/rhpam"
  copyFolder "./installer/kie-server"
  copyFolder "./runtime/kie-server"

  mkdir -p ./tmp_installer
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/jboss-eap/eap-auto.xml > ./tmp_installer/eap-auto.xml
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/kie-server/ks-auto.xml > ././tmp_installer/ks-auto.xml
  copyFolder "./tmp_installer"
  rm -rf ./tmp_installer

  execute "echo \"\" >> /tmp/runtime.properties"
  execute "echo \"EAP_HOME=${EAP_HOME}\" >> /tmp/runtime.properties"
}

function installJdbcDriver(){
  echo "installJdbcDriver"
  execute "curl ${POSTGRESQL_DOWNLOAD_URL} --output /tmp/${POSTGRESQL_DRIVER}"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/postgres-module.cli"
}

function configureDS(){
  echo "configureDS"

  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --properties=/tmp/runtime.properties --file=/tmp/postgres-datasource.cli"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh  --timeout=60000 --file=/tmp/delete-h2.cli"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --connect --timeout=60000 --command='/subsystem=datasources/data-source=KieServerDS:test-connection-in-pool'"
}

function configureController() {
  echo "configureController"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/rhpam-controller.cli"
}

copyResources
installDependencies
stopFirewallService
installEap
installSsoAdapter
installRhpam "ks-auto.xml"
configureSso
installJdbcDriver
startServer
configureDS
configureMavenRepository
configureController
stopServer