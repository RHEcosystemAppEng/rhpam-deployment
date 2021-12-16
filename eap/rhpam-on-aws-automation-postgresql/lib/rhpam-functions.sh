#!/bin/bash

EAP_INSTALLER=jboss-eap-7.3.0-installer.jar
EAP_PATCH=jboss-eap-7.3.6-patch.zip
EAP_SSO_ADAPTER=rh-sso-7.4.0-eap7-adapter.zip

RHPAM_INSTALLER=rhpam-installer-7.9.1.jar

POSTGRESQL_DOWNLOAD_URL=https://jdbc.postgresql.org/download/postgresql-42.3.1.jar
POSTGRESQL_DRIVER=postgresql-42.3.1.jar

function installRhpam(){
  headerLog "installRhpam $1"
  installerXml=$1
  execute "cd /tmp; sudo java -jar ${RHPAM_INSTALLER} /tmp/${installerXml}"
  execute "sudo cp ${EAP_HOME}/standalone/configuration/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml.bak"
}

function configureSso(){
  headerLog "configureSso"
#  startServer
# No JACC
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/keycloak.cli"
#  stopServer
}

function configureMavenRepository(){
  headerLog "configureMavenRepository"
  execute "sudo rm -rf ${RHPAM_DATA_DIR}; sudo mkdir ${RHPAM_DATA_DIR}"
#  execute "sudo mkdir -p ${RHPAM_DATA_DIR}"
  execute "sudo mv /tmp/settings.xml ${RHPAM_DATA_DIR}/settings.xml.template"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/maven-repo.cli"
}

function configureAndStartService(){
  headerLog "configureAndStartService"
  service=$1
  launcher=$2
  echo "configureAndStartService ${service} as ${launcher}"
  execute "sudo systemctl stop ${service};sudo systemctl disable ${service};sudo rm /etc/systemd/system/${service};sudo systemctl daemon-reload;sudo systemctl reset-failed"
  execute "sudo mv /tmp/runtime.properties ${RHPAM_DATA_DIR}"
  execute "sudo mv /tmp/${launcher} ${RHPAM_DATA_DIR}"
  execute "sudo mv /tmp/${service} /etc/systemd/system"
  execute "sudo systemctl start ${service};sudo systemctl enable ${service}"
}