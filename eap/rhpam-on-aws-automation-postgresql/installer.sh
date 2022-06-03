#!/bin/bash

source $(dirname "$0")/installer.properties
source $(dirname "$0")/lib/common-functions.sh
source $(dirname "$0")/lib/eap-functions.sh
source $(dirname "$0")/lib/rhpam-functions.sh

SERVICE_SCRIPT=unset
SERVICE_LAUNCHER=unset
RHPAM_INSTALLER_XML=unset
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
  headerLog "initInstaller"
  rm $(dirname $0)/installer.log
  log "$(date) Starting installation of ${RHPAM_SERVER} on ${RHPAM_SERVER_IP}"
  log "DRY_RUN_ONLY=${DRY_RUN_ONLY}"
  log "SSH_PEM_FILE=${SSH_PEM_FILE}"
  log "SSH_USER_ID=${SSH_USER_ID}"
  log "RHPAM_SERVER_IP=${RHPAM_SERVER_IP}"
  log "RHPAM_SERVER_PORT=${RHPAM_SERVER_PORT}"
  log "RHPAM_SERVER=${RHPAM_SERVER}"
  log "KIE_SERVER_TYPE=${KIE_SERVER_TYPE}"
  log "EAP_HOME=${EAP_HOME}"
  log "RHPAM_HOME=${RHPAM_HOME}"
  log "RHPAM_PROPS_DIR=${RHPAM_PROPS_DIR}"
  log "GIT_HOME=${GIT_HOME}"

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

  log "INSTALL_LOCATION_USE_SUDO=${INSTALL_LOCATION_USE_SUDO}"
  log "INSTALL_LOCATION_IS_REMOTE=${INSTALL_LOCATION_IS_REMOTE}"
  log "SERVICE_SCRIPT=${SERVICE_SCRIPT}"
  log "SERVICE_LAUNCHER=${SERVICE_LAUNCHER}"
  log "RHPAM_INSTALLER_XML=${RHPAM_INSTALLER_XML}"
}

function copyResources(){
  headerLog "copyResources"
  copyFolder "./installer/jboss-eap"
  copyFolder "./installer/rhpam"
  if [ $(isKieServer) ]; then
    copyFolder "./installer/kie-server"
    copyFolder "./runtime/kie-server"
    copyFolder "./runtime/kie-server/${KIE_SERVER_TYPE}"
  else
    copyFolder "./installer/business-central"
    copyFolder "./runtime/business-central"
  fi

  mkdir -p ./${RHPAM_SERVER}_tmp
  sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/jboss-eap/eap-auto.xml > ./${RHPAM_SERVER}_tmp/eap-auto.xml
  if [ $(isKieServer) ]; then
    sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/kie-server/ks-auto.xml > ./${RHPAM_SERVER}_tmp/ks-auto.xml
    sed 's@${RHPAM_HOME}@'$RHPAM_HOME'@;s@${RHPAM_PROPS_DIR}@'$RHPAM_PROPS_DIR'@;s@${KIE_SERVER_TYPE}@'$KIE_SERVER_TYPE'@' \
      ./runtime/kie-server/ks.service > ./${RHPAM_SERVER}_tmp/ks.service
  else
    sed 's@${EAP_HOME}@'$EAP_HOME'@' ./installer/business-central/bc-auto.xml > ./${RHPAM_SERVER}_tmp/bc-auto.xml
    EFS_MOUNT_UNIT=""
    EFS_MOUNT_RECORD=$(execute "systemctl list-units | grep $RHPAM_PROPS_DIR" "no")
    EFS_MOUNT=$(echo $EFS_MOUNT_RECORD | awk '{ print $1 }')
    if [[ $EFS_MOUNT == *'.mount' ]]; then
      EFS_MOUNT_UNIT=$EFS_MOUNT
      # escape any \2xd (hyphens in name of mount file) so that sed below does not interpret them as actual hyphens
      EFS_MOUNT_UNIT="${EFS_MOUNT_UNIT//\x2d/\\x2d}"
    fi
    sed 's@${RHPAM_HOME}@'$RHPAM_HOME'@;s@${RHPAM_PROPS_DIR}@'$RHPAM_PROPS_DIR'@;s@${EFS_MOUNT_UNIT}@'$EFS_MOUNT_UNIT'@' \
      ./runtime/business-central/bc.service > ./${RHPAM_SERVER}_tmp/bc.service
  fi
  copyFolder "./${RHPAM_SERVER}_tmp"
  rm -rf ./${RHPAM_SERVER}_tmp

  execute "echo \"\" >> /tmp/runtime.properties"
  execute "echo \"EAP_HOME=${EAP_HOME}\" >> /tmp/runtime.properties"
  execute "echo \"RHPAM_HOME=${RHPAM_HOME}\" >> /tmp/runtime.properties"
  execute "echo \"RHPAM_SERVER_PORT=${RHPAM_SERVER_PORT}\" >> /tmp/runtime.properties"
  if [ ! $(isKieServer) ]; then
    execute "echo \"GIT_HOME=${GIT_HOME}\" >> /tmp/runtime.properties"
  fi
}

### Business Central functions ###
function configureGitRepository() {
  headerLog "configureGitRepository"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/git.cli"
}

function configureKieServer() {
  headerLog "configureKieServer"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/rhpam-kieserver.cli"
}

function patchUnauthenticatedMethods() {
  headerLog "patchUnauthenticatedMethods"
  execute "sudo sed -i 's/.*\(<deny-uncovered-http-methods \/>\).*/<!--\1-->/' ${EAP_HOME}/standalone/deployments/kie-server.war/WEB-INF/web.xml"
}

### Kie Server functions ###
function configurePostgresQL() {
  headerLog "configurePostgresQL"
  unzip -o ./installer/database/rhpam-7.9.1-add-ons.zip -d ./installer/database rhpam-7.9.1-migration-tool.zip
  rm -rf installer/database/rhpam-7.9.1-migration-tool
  unzip -o ./installer/database/rhpam-7.9.1-migration-tool.zip -d ./installer/database/ "rhpam-7.9.1-migration-tool/ddl-scripts/postgresql/postgresql-jbpm-schema.sql"
  unzip -o ./installer/database/rhpam-7.9.1-migration-tool.zip -d ./installer/database/ "rhpam-7.9.1-migration-tool/ddl-scripts/postgresql/quartz_tables_postgres.sql"
  unzip -o ./installer/database/rhpam-7.9.1-migration-tool.zip -d ./installer/database/ "rhpam-7.9.1-migration-tool/ddl-scripts/postgresql/task_assigning_tables_postgresql.sql"
  cd ./installer/database/rhpam-7.9.1-migration-tool/ddl-scripts && zip -r ../../postgresql.zip  postgresql && cd -
  cd ./installer/database && zip -urv postgresql.zip customSql/*.sql && cd -
  copyFile "./installer/database" "postgresql.zip"
  rm -rf installer/database/rhpam-7.9.1-migration-tool
  rm -f installer/database/rhpam-7.9.1-migration-tool.zip
  rm -f installer/database/postgresql.zip

  execute "/tmp/postgresql.sh"
}

function configureMySQL() {
  headerLog "configureMySQL"
  unzip -o ./installer/database/rhpam-7.9.1-add-ons.zip -d ./installer/database rhpam-7.9.1-migration-tool.zip
  rm -rf installer/database/rhpam-7.9.1-migration-tool
  unzip -o ./installer/database/rhpam-7.9.1-migration-tool.zip -d ./installer/database/ "rhpam-7.9.1-migration-tool/ddl-scripts/mysqlinnodb/mysql-innodb-jbpm-schema.sql"
  unzip -o ./installer/database/rhpam-7.9.1-migration-tool.zip -d ./installer/database/ "rhpam-7.9.1-migration-tool/ddl-scripts/mysqlinnodb/quartz_tables_mysql_innodb.sql"
  unzip -o ./installer/database/rhpam-7.9.1-migration-tool.zip -d ./installer/database/ "rhpam-7.9.1-migration-tool/ddl-scripts/mysqlinnodb/task_assigning_tables_mysql_innodb.sql"
  cd ./installer/database/rhpam-7.9.1-migration-tool/ddl-scripts && zip -r ../../mysqlinnodb.zip  mysqlinnodb && cd -
  cd ./installer/database && zip -urv mysqlinnodb.zip customSql/*.sql && cd -
  copyFile "./installer/database" "mysqlinnodb.zip"
  rm -rf installer/database/rhpam-7.9.1-migration-tool
  rm -f installer/database/rhpam-7.9.1-migration-tool.zip
  rm -f installer/database/mysqlinnodb.zip

  execute "/tmp/mysqlinnodb.sh"
}

function installJdbcDriver(){
  headerLog "installJdbcDriver"
  if [[ ${DB_TYPE} == 'mysql' ]]; then
    execute "curl -L ${MYSQL_DOWNLOAD_URL} --output /tmp/mysql.zip"
    execute "unzip -o /tmp/mysql.zip -d /tmp ${MYSQL_DRIVER}"
    execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/mysql-module.cli"
  elif [[ ${DB_TYPE} == 'postgresql' ]]; then
    execute "curl ${POSTGRESQL_DOWNLOAD_URL} --output /tmp/${POSTGRESQL_DRIVER}"
    execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --file=/tmp/postgres-module.cli"
  fi
}

function configureDS(){
  headerLog "configureDS"
  if [[ ${DB_TYPE} == 'mysql' ]]; then
    execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --properties=/tmp/runtime.properties --file=/tmp/mysql-datasource.cli"
  elif [[ ${DB_TYPE} == 'postgresql' ]]; then
    execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --properties=/tmp/runtime.properties --file=/tmp/postgres-datasource.cli"
  fi
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh  --timeout=60000 --file=/tmp/delete-h2.cli"
  execute "sudo ${EAP_HOME}/bin/jboss-cli.sh --connect --timeout=60000 --command='/subsystem=datasources/data-source=KieServerDS:test-connection-in-pool'"
}

function configureController() {
  headerLog "configureController"
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
  installDependencies $(isKieServer)
  stopFirewallService
fi
if [ $(isKieServer) ]; then
  if [[ ${DB_TYPE} == 'mysql' ]]; then
    configureMySQL
  elif [[ ${DB_TYPE} == 'postgresql' ]]; then
    configurePostgresQL
  else
    log "Unsupported DB_TYPE=${DB_TYPE}-Exiting"
    exit 1
  fi
fi
installEap
installSsoAdapter
installRhpam "${RHPAM_INSTALLER_XML}"
if [ $(isKieServer) ]; then
  patchUnauthenticatedMethods
fi
configureSso
if [ $(isKieServer) ]; then
  installJdbcDriver
  configureDS
fi
configureMavenRepository
if [ $(isKieServer) ]; then
  configureController
else
  configureGitRepository
  configureKieServer
fi
configureAndStartService "${SERVICE_SCRIPT}" "${SERVICE_LAUNCHER}"
logService "${SERVICE_SCRIPT}"
