#!/bin/bash

source kie-server.properties

function execute() {
  cmd=$1
  echo "=== $cmd ==="
  ssh -i ${SSH_PEM_FILE} ec2-user@$KIE_SERVER_IP "${cmd}"
}

function copyResources(){
  scp -i ${SSH_PEM_FILE} ./resources/jboss-eap/* ec2-user@$KIE_SERVER_IP:/tmp
  scp -i ${SSH_PEM_FILE} ./resources/rhpam/* ec2-user@$KIE_SERVER_IP:/tmp
  scp -i ${SSH_PEM_FILE} ./resources/kie-server/* ec2-user@$KIE_SERVER_IP:/tmp

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
  execute "cd /tmp; sudo java -jar /tmp/jboss-eap-7.3.0-installer.jar /tmp/eap-auto.xml"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --command='patch apply /tmp/jboss-eap-7.3.9-patch.zip'"
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
  execute "sudo unzip /tmp/rh-sso-7.4.9-eap7-adapter-dist.zip -d ${EAP_HOME}"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=${EAP_HOME}/bin/adapter-elytron-install-offline.cli -Dserver.config=standalone-full.xml"

  startServer
# No JACC
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/keycloak.cli"

  stopServer
}

function installKieServer(){
  echo "installKieServer"
  execute "cd /tmp; sudo java -jar rhpam-installer-7.11.1.jar /tmp/ks-auto.xml"
  execute "sudo cp ${EAP_HOME}/standalone/configuration/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml.bak"
}

function configureDS(){
  echo "configureDS"
  execute "curl https://jdbc.postgresql.org/download/postgresql-42.3.1.jar --output /tmp/postgresql-42.3.1.jar"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/postgres-module.cli"

  startServer

  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --properties=/tmp/runtime.properties --file=/tmp/postgres-datasource.cli"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh  --timeout=60000 --file=/tmp/delete-h2.cli"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --connect --timeout=60000 --command='/subsystem=datasources/data-source=KieServerDS:test-connection-in-pool'"
}

function configureUsers(){
  echo "configureUsers"
  execute "echo \"\" >> /tmp/runtime.properties"
  execute "echo \"rhpamController_username=${CONTROLLER_USERNAME}\" >> /tmp/runtime.properties"
  execute "echo \"rhpamController_password=${CONTROLLER_PASSWORD}\" >> /tmp/runtime.properties"
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
configureUsers
configureController
stopServer