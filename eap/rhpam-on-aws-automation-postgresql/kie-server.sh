#!/bin/bash

source $(dirname "$0")/kie-server.properties
source $(dirname "$0")/lib/rhpam-common.sh

function execute() {
  cmd=$1
  echo "=== $cmd ==="
  ssh -i ${SSH_PEM_FILE} ${SSH_USER_ID}@$KIE_SERVER_IP "${cmd}"
}

function copyResources(){
#  scp -i ${SSH_PEM_FILE} ./resources/jboss-eap/* ${SSH_USER_ID}@$KIE_SERVER_IP:/tmp
#  scp -i ${SSH_PEM_FILE} ./resources/rhpam/* ${SSH_USER_ID}@$KIE_SERVER_IP:/tmp
  scp -i ${SSH_PEM_FILE} ./resources/kie-server/* ${SSH_USER_ID}@$KIE_SERVER_IP:/tmp

  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./resources/jboss-eap/eap-auto.xml > ./resources/jboss-eap/eap-auto-updated.xml
  scp -i ${SSH_PEM_FILE} ./resources/jboss-eap/eap-auto-updated.xml ${SSH_USER_ID}@$KIE_SERVER_IP:/tmp/eap-auto.xml
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./resources/kie-server/ks-auto.xml > resources/kie-server/ks-auto-updated.xml
  scp -i ${SSH_PEM_FILE} resources/kie-server/ks-auto-updated.xml ${SSH_USER_ID}@$KIE_SERVER_IP:/tmp/ks-auto.xml
  execute "echo \"\" >> /tmp/runtime.properties"
  execute "echo \"EAP_HOME=${EAP_HOME}\" >> /tmp/runtime.properties"
}

function waitForServer() {
  echo "$(date) Waiting for http://${KIE_SERVER_IP}:8080"
  until $(curl --output /dev/null --silent --head --fail http://${KIE_SERVER_IP}:8080); do
      printf '.'
      sleep 5
  done
  echo "$(date) Server is up"
}

function installEap(){
  echo "installEap"
  stopServer
  execute "sudo rm -rf ${EAP_HOME}; sudo mkdir ${EAP_HOME}"
  execute "cd /tmp; sudo java -jar /tmp/${EAP_INSTALLER} /tmp/eap-auto.xml"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --command='patch apply /tmp/${EAP_PATCH}'"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --command='patch history'"
}

function startServer(){
  execute "cd /tmp; sh -c 'sudo /tmp/run-service.sh > /dev/null 2>&1 &'"
  waitForServer
}

function stopServer(){
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --connect --timeout=60000 --command=shutdown"
}

function installSsoAdapter(){
  execute "sudo unzip /tmp/${EAP_SSO_ADAPTER} -d ${EAP_HOME}"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=${EAP_HOME}/bin/adapter-elytron-install-offline.cli -Dserver.config=standalone-full.xml"

  startServer
# No JACC
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/keycloak.cli"

  stopServer
}

function installKieServer(){
  echo "installKieServer"
  execute "cd /tmp; sudo java -jar ${RHPAM_INSTALLER} /tmp/ks-auto.xml"
  execute "sudo cp ${EAP_HOME}/standalone/configuration/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml.bak"
}

function configureDS(){
  echo "configureDS"
  execute "curl ${POSTGRESQL_DOWNLOAD_URL} --output /tmp/${POSTGRESQL_DRIVER}"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/postgres-module.cli"

  startServer

  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --properties=/tmp/runtime.properties --file=/tmp/postgres-datasource.cli"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh  --timeout=60000 --file=/tmp/delete-h2.cli"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --connect --timeout=60000 --command='/subsystem=datasources/data-source=KieServerDS:test-connection-in-pool'"
}

function configureController() {
  echo "configureController"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/rhpam-controller.cli"
}

function configureMavenRepository(){
  echo "configureMavenRepository"
  execute "sudo mkdir /opt/custom-config"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/maven-repo.cli"
}

copyResources
installEap
installSsoAdapter
installKieServer
configureDS
configureMavenRepository
configureController
stopServer