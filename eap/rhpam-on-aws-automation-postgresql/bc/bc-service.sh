#!/bin/bash
source /opt/custom-config/business-central.properties

${EAP_HOME}/bin/standalone.sh -c standalone-full.xml -b 0.0.0.0 \
-Drhpam.sso.auth.url=${SSO_AUTH_URL} \
-Dbusiness.central.client.secret=${SSO_BC_SECRET} \
-Dorg.kie.server.user=${KIESERVER_USERNAME} \
-Dorg.kie.server.pwd=${KIESERVER_PASSWORD}

#-Drhpam.sso.token=${SSO_BC_SECRET}  \