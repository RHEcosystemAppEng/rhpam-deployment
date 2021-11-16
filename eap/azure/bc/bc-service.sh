#!/bin/bash
source /opt/custom-config/deployment.properties

${EAP_HOME}/bin/standalone.sh -c standalone-full.xml -b 0.0.0.0
