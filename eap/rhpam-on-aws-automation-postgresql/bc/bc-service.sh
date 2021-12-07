#!/bin/bash
source /opt/custom-config/business-central.properties

${EAP_HOME}/bin/standalone.sh -c standalone-full.xml -b 0.0.0.0 \
-Drhpam.sso.token=${SSO_BC_SECRET}  \
-Drhpam.sso.auth_url=${SSO_AUTH_URL} \
-Dbusiness.central.client.secret=${SSO_KS_SECRET} \
-Dorg.kie.server.user=${CONTROLLER_USERNAME} \
-Dorg.kie.server.pwd=${CONTROLLER_PASSWORD} 
