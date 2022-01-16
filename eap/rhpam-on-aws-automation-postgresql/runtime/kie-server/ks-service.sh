#!/bin/bash

RHPAM_PROPS_DIR=$1
echo "Starting from ${RHPAM_PROPS_DIR}/runtime.properties"
source ${RHPAM_PROPS_DIR}/runtime.properties

function updateMavenSettings(){
  sed 's/${MAVEN_REPO_USERNAME}/'$MAVEN_REPO_USERNAME'/g ; s/${MAVEN_REPO_PASSWORD}/'$MAVEN_REPO_PASSWORD'/g ; s@${MAVEN_REPO_URL}@'$MAVEN_REPO_URL'@' \
    $(dirname "$0")/settings.xml.template > ${RHPAM_HOME}/settings.xml
}

function updateDeploymentFromKS(){
  bc_url=$1
  ks_privateIp=$2

  kieserver_userdata=$(get_userdata)
  if [[ "${kieserver_userdata}" == *"latest-artifact-gav"* ]]; then
    server_id="ip-$(echo "${ks_privateIp}" | tr . -)"
    echo "***server_id:"$server_id

    curl -v --user 'rhpamadmin:redhat123#' -H "Accept: application/json" -X GET "${bc_url}/business-central/rest/controller/management/servers" -o existing_servers.json
    serverExists=false
    for i in $(jq -r '."server-template"[] | ."server-id"' existing_servers.json); do
        if [[ $i == "${server_id}" ]]; then
          serverExists=true
        fi
    done
    echo $serverExists
    rm existing_servers.json

    if [[ $serverExists != true ]]; then
      # 1st startup after auto scale => instance is not registered yet with BC -> create server with deployment
      artifactValue=$(echo "${kieserver_userdata}" | cut -d"=" -f2)
      echo "***artifactValue:"$artifactValue
      groupId=$(echo "${artifactValue}" | cut -d":" -f1)
      artifactId=$(echo "${artifactValue}" | cut -d":" -f2)
      version=$(echo "${artifactValue}" | cut -d":" -f3)

      sed 's@$server_id@'$server_id'@;s@$artifact_id@'$artifactId'@;s@$group_id@'$groupId'@;s@$version@'$version'@' \
            ./new-server-template.json > ./new-server.json

      curl --user 'rhpamadmin:redhat123#' -H "Accept: application/json" -H "Content-Type: application/json" -X PUT "${bc_url}/business-central/rest/controller/management/servers/${server_id}" -d @new-server.json
      rm new-server.json
    fi
    # for any other subsequent ks service restart do nothing
  fi
}

function get_private_ip() {
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") &&
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4
}

function get_hostname() {
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") &&
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-hostname | cut -d'.' -f1
}

function get_userdata(){
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") &&
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/user-data
}

updateMavenSettings
kieserver_privateIp=$(get_private_ip)
kieserver_hostname=$(get_hostname)
updateDeploymentFromKS "${businessCentral_url}" "${kieserver_privateIp}"

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
  -DbusinessCentral_url=${businessCentral_url} -DrhpamController_username=${rhpamController_username} -DrhpamController_password=${rhpamController_password} \
  -Drhpam_server_data_dir=${RHPAM_HOME}
