#!/bin/bash

source keycloak-functions.sh

login
createRealm ${REALM_NAME}
for role in ${ROLES}; do
   createRealmRole ${REALM_NAME} ${role}
done
defineUser "${REALM_NAME}" "${USER1}"
defineUser "${REALM_NAME}" "${USER2}"
defineUser "${REALM_NAME}" "${USER3}"
addClientRoleToUser ${REALM_NAME} "${USER1}" "realm-management" "realm-admin"
createClient ${REALM_NAME} "business-central" "-s protocol=openid-connect -s rootUrl=${BC_URL} -s redirectUris=[\"${BC_URL}/*\",\"${BC_HTTPS_URL}/*\"] -s bearerOnly=false -s publicClient=false"
createClient ${REALM_NAME} "kie-server" "-s protocol=openid-connect -s rootUrl=${KS_URL} -s bearerOnly=false -s publicClient=false"
