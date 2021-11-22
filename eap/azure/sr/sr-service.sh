#!/bin/bash
source /opt/custom-config/deployment.properties
SMART_ROUTER_SERVER_PRIVATE_IP=0.0.0.0
java \
   -Dorg.kie.server.router.host=${SMART_ROUTER_SERVER_PRIVATE_IP} \
   -Dorg.kie.server.router.port=${SMART_ROUTER_PORT} \
   -Dorg.kie.server.router.config.watcher.enabled=false \
   -Dorg.kie.server.router.repo=${SMART_ROUTER_HOME}/repo \
   -jar ${SMART_ROUTER_HOME}/rhpam-7.9.0-smart-router.jar