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
  controller_user=$3
  controller_pwd=$4

  kieserver_userdata=$(get_userdata)
  echo "***user-data:${kieserver_userdata}"
  if [[ "${kieserver_userdata}" == *"artifacts"* ]]; then
    server_id="ip-$(echo "${ks_privateIp}" | tr . -)"
    echo "***server_id:"$server_id

    curl -v --user "${controller_user}:${controller_pwd}" -H "Accept: application/json" -X GET "${bc_url}/business-central/rest/controller/management/servers" -o /tmp/existing_servers.json
    serverExists=false
    for i in $(jq -r '."server-template"[] | ."server-id"' /tmp/existing_servers.json); do
        if [[ $i == "${server_id}" ]]; then
          serverExists=true
        fi
    done
    rm /tmp/existing_servers.json

    echo "***server exists:${serverExists}"
    if [[ "${serverExists}" != true ]]; then
      # 1st startup after auto scale => instance is not registered yet with BC -> create server with deployments
      bc_host=${bc_url##*/}
      sed 's@$server_id@'$server_id'@;s@$bc_host@'$bc_host'@;s@$bc_url@'$bc_url'@' \
                 ${RHPAM_PROPS_DIR}/new-server-template.json > /tmp/new-server.json
      curl --user "${controller_user}:${controller_pwd}" -H "Accept: application/json" -H "Content-Type: application/json" -X PUT "${bc_url}/business-central/rest/controller/management/servers/${server_id}" -d @/tmp/new-server.json
      rm /tmp/new-server.json

      artifacts=$(echo "${kieserver_userdata}" | jq '.artifacts')
      echo "***artifacts to deploy:${artifacts}"
      for i in $(echo "${artifacts}" | jq -c '.[]'); do
        groupId=$(echo "$i" | jq -r '.group_id')
        artifactId=$(echo "$i" | jq -r '.artifact_id')
        version=$(echo "$i" | jq -r '.version')
        echo "***gav:${groupId} ${artifactId} ${version}"
        sed 's@$server_id@'$server_id'@;s@$artifact_id@'$artifactId'@;s@$group_id@'$groupId'@;s@$version@'$version'@' \
                  ${RHPAM_PROPS_DIR}/new-container-template.json > /tmp/new-container.json
        curl --user "${controller_user}:${controller_pwd}" -H "Accept: application/json" -H "Content-Type: application/json" -X PUT "${bc_url}/business-central/rest/controller/management/servers/${server_id}/containers/${artifactId}_${version}" -d @/tmp/new-container.json
        rm /tmp/new-container.json
      done
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
updateDeploymentFromKS "${businessCentral_url}" "${kieserver_privateIp}" "${rhpamController_username}" "${rhpamController_password}"

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
