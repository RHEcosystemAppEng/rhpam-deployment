#!/bin/bash

source /tmp/keycloak.properties

echo "starting server"
${KEYCLOAK_HOME}/bin/standalone.sh -b 0.0.0.0

