#!/bin/bash

function installEap(){
  stopServer
  echo "******************** installEap ********************"
  execute "sudo rm -rf ${EAP_HOME}; sudo mkdir ${EAP_HOME}"
  execute "cd /tmp; sudo java -jar /tmp/${EAP_INSTALLER} /tmp/eap-auto.xml"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --command='patch apply /tmp/${EAP_PATCH}'"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --command='patch history'"
}

function installSsoAdapter(){
  echo "******************** installSsoAdapter ********************"
  execute "sudo unzip /tmp/${EAP_SSO_ADAPTER} -d ${EAP_HOME}"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=${EAP_HOME}/bin/adapter-elytron-install-offline.cli -Dserver.config=standalone-full.xml"
}