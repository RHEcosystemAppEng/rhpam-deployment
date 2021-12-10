#!/bin/bash

EAP_INSTALLER=jboss-eap-7.3.0-installer.jar
EAP_PATCH=jboss-eap-7.3.6-patch.zip
EAP_SSO_ADAPTER=rh-sso-7.4.0-eap7-adapter.zip

RHPAM_INSTALLER=rhpam-installer-7.9.1.jar

POSTGRESQL_DOWNLOAD_URL=https://jdbc.postgresql.org/download/postgresql-42.3.1.jar
POSTGRESQL_DRIVER=postgresql-42.3.1.jar

function installRhpam(){
  echo "installRhpam $1"
  installerXml=$1
  execute "cd /tmp; sudo java -jar ${RHPAM_INSTALLER} /tmp/${installerXml}"
  execute "sudo cp ${EAP_HOME}/standalone/configuration/standalone-full.xml ${EAP_HOME}/standalone/configuration/standalone-full.xml.bak"
}

function configureSso(){
    startServer
  # No JACC
    execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/keycloak.cli"
    stopServer
}

function configureMavenRepository(){
  echo "configureMavenRepository"
  execute "sudo mkdir -p /opt/custom-config"
  execute "sudo mv /tmp/settings.xml /opt/custom-config/settings.xml.template"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/maven-repo.cli"
}
