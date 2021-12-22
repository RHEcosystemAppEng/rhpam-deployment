#!/bin/bash

source keycloak-functions.sh

# to be able to reuse some common functions, instantiate variables used there
RHPAM_SERVER_IP=$KEYCLOAK_SERVER_IP
RHPAM_SERVER_PORT=$KEYCLOAK_SERVER_PORT
EAP_HOME=$KEYCLOAK_HOME
RHPAM_HOME=$KEYCLOAK_DATA_DIR

# this script is run on the machine where we need to install keycloak => the INSTALL_LOCATION_IS_REMOTE is always false
INSTALL_LOCATION_IS_REMOTE=false
INSTALL_LOCATION_USE_SUDO=true
if [ ${INSTALL_TYPE} == 'LOCAL' ]
then
  INSTALL_LOCATION_USE_SUDO=false
fi

SERVICE_SCRIPT="keycloak.service"
SERVICE_LAUNCHER="keycloak-service.sh"

if [[ ${INSTALL_TYPE} == 'REMOTE_FULL' ]]; then
  installDependencies
  stopFirewallService
fi
if [[ ${INSTALL_TYPE} != 'REMOTE_PARTIAL' ]]; then
  installKeycloak
fi

startServer
login
createRealm ${REALM_NAME}
for role in ${ROLES}; do
   createRealmRole ${REALM_NAME} ${role}
done
defineUser "${USER1}"
defineUser "${USER2}"
defineUser "${USER3}"
addClientRoleToUser ${REALM_NAME} "${USER1}" "realm-management" "realm-admin"
createClient ${REALM_NAME} "business-central" "-s protocol=openid-connect -s rootUrl=${BC_URL} -s redirectUris=[\"${BC_URL}/*\",\"${BC_HTTPS_URL}/*\"] -s bearerOnly=false -s publicClient=false"
createClient ${REALM_NAME} "kie-server" "-s protocol=openid-connect -s rootUrl=${KS_URL} -s bearerOnly=false -s publicClient=false"

if [[ ${INSTALL_TYPE} == 'REMOTE_FULL' ]]; then
  stopServer
  configureAndStartService "${SERVICE_SCRIPT}" "${SERVICE_LAUNCHER}"
  logService "${SERVICE_SCRIPT}"
fi