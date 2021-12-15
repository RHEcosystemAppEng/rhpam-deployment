#!/bin/bash

source $(dirname "$0")/installer.properties
source $(dirname "$0")/lib/common-functions.sh
source $(dirname "$0")/lib/eap-functions.sh
source $(dirname "$0")/lib/rhpam-functions.sh

SERVICE_SCRIPT=unset
SERVICE_LAUNCHER=unset
RHPAM_INSTALLER_XML=unset
RHPAM_SERVER_PORT=unset
INSTALL_LOCATION_USE_SUDO=unset
INSTALL_LOCATION_IS_REMOTE=unset

function isKieServer() {
  if [[ "$RHPAM_SERVER" == "kie-server" ]]; then
    echo "true"
  else
    echo ""
  fi
}

function initInstaller() {
  rm $(dirname $0)/installer.log
  log "$(date) Starting installation of ${RHPAM_SERVER} on ${RHPAM_SERVER_IP}"
  log "DRY_RUN_ONLY=${DRY_RUN_ONLY}"
  log "SSH_PEM_FILE=${SSH_PEM_FILE}"
  log "SSH_USER_ID=${SSH_USER_ID}"
  log "RHPAM_SERVER_IP=${RHPAM_SERVER_IP}"
  log "RHPAM_SERVER_PORT_OFFSET=${RHPAM_SERVER_PORT_OFFSET}"
  log "RHPAM_SERVER=${RHPAM_SERVER}"
  log "KIE_SERVER_TYPE=${KIE_SERVER_TYPE}"
  log "EAP_HOME=${EAP_HOME}"
  log "RHPAM_DATA_DIR=${RHPAM_DATA_DIR}"

  RHPAM_SERVER_PORT=$(getPortWithOffset ${RHPAM_SERVER_PORT_OFFSET})
  INSTALL_LOCATION_USE_SUDO=true
  INSTALL_LOCATION_IS_REMOTE=true
  if [ ${INSTALL_TYPE} == 'LOCAL' ]
  then
    INSTALL_LOCATION_USE_SUDO=false
    INSTALL_LOCATION_IS_REMOTE=false
  fi
  if [[ $(isKieServer) ]]; then
    SERVICE_SCRIPT="ks.service"
    SERVICE_LAUNCHER="ks-service.sh"
    RHPAM_INSTALLER_XML="ks-auto.xml"
  else
    SERVICE_SCRIPT="bc.service"
    SERVICE_LAUNCHER="bc-service.sh"
    RHPAM_INSTALLER_XML="bc-auto.xml"
  fi

  log "RHPAM_SERVER_PORT=${RHPAM_SERVER_PORT}"
  log "INSTALL_LOCATION_USE_SUDO=${INSTALL_LOCATION_USE_SUDO}"
  log "INSTALL_LOCATION_IS_REMOTE=${INSTALL_LOCATION_IS_REMOTE}"
  log "SERVICE_SCRIPT=${SERVICE_SCRIPT}"
  log "SERVICE_LAUNCHER=${SERVICE_LAUNCHER}"
  log "RHPAM_INSTALLER_XML=${RHPAM_INSTALLER_XML}"
}

function copyResources(){
  echo "copyResources"
  copyFolder "./installer/jboss-eap"
  copyFolder "./installer/rhpam"
  if [ $(isKieServer) ]; then
    copyFolder "./installer/kie-server"
    copyFolder "./runtime/kie-server"
  else
    copyFolder "./installer/business-central"
    copyFolder "./runtime/business-central"
  fi

  mkdir -p ./${RHPAM_SERVER}_tmp
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/jboss-eap/eap-auto.xml > ./${RHPAM_SERVER}_tmp/eap-auto.xml
  if [ $(isKieServer) ]; then
    sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/kie-server/ks-auto.xml > ./${RHPAM_SERVER}_tmp/ks-auto.xml
  else
    sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/business-central/bc-auto.xml > ./${RHPAM_SERVER}_tmp/bc-auto.xml
  fi
  copyFolder "./${RHPAM_SERVER}_tmp"
  rm -rf ./${RHPAM_SERVER}_tmp

  execute "echo \"\" >> /tmp/runtime.properties"
  execute "echo \"EAP_HOME=${EAP_HOME}\" >> /tmp/runtime.properties"
  execute "echo \"RHPAM_DATA_DIR=${RHPAM_DATA_DIR}\" >> /tmp/runtime.properties"

}

### Business Central functions ###
function configureKieServer() {
  echo "******************** configureKieServer ********************"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/rhpam-kieserver.cli"
}

### Kie Server functions ###
function configurePostgresQL() {
  echo "******************** configurePostgresQL ********************"
  unzip ./installer/database/rhpam-7.9.1-add-ons.zip -d ./installer/database/ rhpam-7.9.1-migration-tool.zip
  rm -rf installer/database/rhpam-7.9.1-migration-tool
  unzip  ./installer/database/rhpam-7.9.1-migration-tool.zip -d ./installer/database/ "rhpam-7.9.1-migration-tool/ddl-scripts/postgresql/postgresql-jbpm-schema.sql"
  unzip  ./installer/database/rhpam-7.9.1-migration-tool.zip -d ./installer/database/ "rhpam-7.9.1-migration-tool/ddl-scripts/postgresql/quartz_tables_postgres.sql"
  unzip  ./installer/database/rhpam-7.9.1-migration-tool.zip -d ./installer/database/ "rhpam-7.9.1-migration-tool/ddl-scripts/postgresql/task_assigning_tables_postgresql.sql"
  cd ./installer/database/rhpam-7.9.1-migration-tool/ddl-scripts && zip -r ../../postgresql.zip  postgresql && cd -
  copyFile "./installer/database" "postgresql.zip"

  execute "/tmp/postgresql.sh"
}

function installJdbcDriver(){
  echo "******************** installJdbcDriver ********************"
  execute "curl ${POSTGRESQL_DOWNLOAD_URL} --output /tmp/${POSTGRESQL_DRIVER}"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/postgres-module.cli"
}

function configureDS(){
  echo "******************** configureDS ********************"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --properties=/tmp/runtime.properties --file=/tmp/postgres-datasource.cli"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh  --timeout=60000 --file=/tmp/delete-h2.cli"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --connect --timeout=60000 --command='/subsystem=datasources/data-source=KieServerDS:test-connection-in-pool'"
}

function configureController() {
  echo "******************** configureController ********************"
  if [[ ${KIE_SERVER_TYPE} == "unmanaged" ]]; then
    execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/rhpam-unmanaged-server.cli"
  else
    execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/rhpam-managed-server.cli"
  fi
}
### Main

initInstaller
copyResources
if [[ ${INSTALL_TYPE} == 'REMOTE_FULL' ]]; then
  installDependencies
  stopFirewallService
fi
if [ $(isKieServer) ]; then
  configurePostgresQL
fi
installEap
installSsoAdapter
installRhpam "${RHPAM_INSTALLER_XML}"
configureSso
if [ $(isKieServer) ]; then
  installJdbcDriver
  configureDS
fi
configureMavenRepository
if [ $(isKieServer) ]; then
  configureController
else
  configureKieServer
fi
if [[ ${INSTALL_TYPE} == 'REMOTE_FULL' ]]; then
  configureAndStartService "${SERVICE_SCRIPT}" "${SERVICE_LAUNCHER}"
  logService "${SERVICE_SCRIPT}"
fi
if [[ ${INSTALL_TYPE} == 'LOCAL' ]]; then
  startServer
fi
