#!/bin/bash
source /opt/custom-config/deployment.properties

KS_HOST=`hostname`
echo "Starting ${KS_HOST}:${KIE_SERVER_PORT} with Business Central defined at (if relevant) ${BUSINESS_CENTRAL_HOSTNAME}:${BUSINESS_CENTRAL_PORT} and Smart Router at (if relevant) ${SMART_ROUTER_HOST}:${SMART_ROUTER_PORT} "
${EAP_HOME}/bin/standalone.sh -c standalone-full.xml -b 0.0.0.0 \
            -Dbusiness.central.host=${BUSINESS_CENTRAL_HOSTNAME} -Dbusiness.central.port=${BUSINESS_CENTRAL_PORT} \
            -Dkie.server.host=${KS_HOST} -Dkie.server.port=${KIE_SERVER_PORT} \
            -Dsmart.router.host=${SMART_ROUTER_HOST} -Dsmart.router.port=${SMART_ROUTER_PORT}
i