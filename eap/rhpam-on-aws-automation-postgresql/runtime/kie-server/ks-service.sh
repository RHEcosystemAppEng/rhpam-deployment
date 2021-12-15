#!/bin/bash

source $(dirname "$0")/runtime.properties

function updateMavenSettings(){
  sed 's@${MAVEN_REPO_USERNAME}@'$MAVEN_REPO_USERNAME'@g ; s@${MAVEN_REPO_PASSWORD}@'$MAVEN_REPO_PASSWORD'@g ; s@${MAVEN_REPO_URL}@'$MAVEN_REPO_URL'@' \
    $(dirname "$0")/settings.xml.template > /opt/custom-config/settings.xml
}

function get_private_ip() {
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") &&
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4
}

function get_hostname() {
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") &&
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-hostname | cut -d'.' -f1
}

updateMavenSettings
kieserver_privateIp=$(get_private_ip)
kieserver_hostname=$(get_hostname)

echo "#######################################################################"
echo "Running KIE Server from ${kieserver_privateIp} as ${kieserver_hostname}"
echo "#######################################################################"

${EAP_HOME}/bin/standalone.sh -c standalone-full.xml -b 0.0.0.0 \
  -Ddatabase_host=${database_host} -Ddatabase_port=${database_port} -Ddatabase_schema=${database_schema}\
  -Ddatabase_credential_username=${database_credential_username} -Ddatabase_credential_password=${database_credential_password}\
  -DkeycloakSso_authUrl=${keycloakSso_authUrl} -DkeycloakSso_realm_name=${keycloakSso_realm_name} \
  -DkeycloakSso_deployment=kie-server.war \
  -DkeycloakSso_realm_client_name=${keycloakSso_realm_client_name} -DkeycloakSso_realm_client_secret=${keycloakSso_realm_client_secret} \
  -Dkieserver_privateIp=${kieserver_privateIp} -Dkieserver_hostname=${kieserver_hostname} -Dkieserver_port=${RHPAM_SERVER_PORT} \
  -DbusinessCentral_host=${businessCentral_host} --DbusinessCentral_port=${businessCentral_port} -DrhpamController_username=${rhpamController_username} -DrhpamController_password=${rhpamController_password} \
  -Drhpam_server_data_dir=${RHPAM_DATA_DIR}
