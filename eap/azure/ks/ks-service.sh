#!/bin/bash
source /opt/custom-config/deployment.properties

KS_HOST=`hostname`
echo "Starting ${KS_HOST}"
${EAP_HOME}/bin/standalone.sh -c standalone-full.xml -b 0.0.0.0 \
            -Dbusiness.central.host=${BUSINESS_CENTRAL_HOSTNAME} -Dbusiness.central.port=8080 \
            -Dkie.server.host=${KS_HOST}
