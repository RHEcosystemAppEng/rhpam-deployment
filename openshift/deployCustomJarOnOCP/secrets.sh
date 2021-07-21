#!/bin/bash

DNAME="CN=dmartino.redhat.com,OU=Ecosystem Engineering,O=redhat.com,L=Raleigh,S=NC,C=US"

create_secret() {
  service_name=$1
  echo "==>Installing certificate secret for ${service_name}"
  [ -f keystore.jks ] && rm keystore.jks
  keytool -genkeypair -alias ${service_name} -keyalg RSA -keystore keystore.jks \
    -storetype JKS -keypass password -storepass password --dname "${DNAME}"

  oc delete secret ${service_name}-app-secret --ignore-not-found
  oc create secret generic ${service_name}-app-secret --from-file=keystore.jks
  rm keystore.jks
}

create_secret kieserver
create_secret businesscentral
create_secret broker
create_secret smartrouter
