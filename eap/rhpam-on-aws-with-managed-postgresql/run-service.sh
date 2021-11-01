#!/bin/bash

show_usage() {
  echo "Script for running RHPAM components as system services"
  echo "------------------------------------------------------"
  echo "Usage: $0 -h/--help"
  echo "Usage: $0 <service>"
  echo "	<service> is one of: rh-sso, business-central, kie-server, smart-router"
}

function is_awsEC2() {
  if $(curl -s -m 5 http://169.254.169.254/latest/dynamic/instance-identity/document | grep -q availabilityZone); then
    echo "yes"
  else
    echo "no"
  fi
}

function get_private_ip() {
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") &&
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4
}

function get_public_ip() {
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") &&
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/public-ipv4
}

function get_sso_token() {
  echo $(curl -s --data "grant_type=password&client_id=${1}&client_secret=${2}&username=${rh_sso_rhpam_username}&password=${rh_sso_rhpam_password}" \
  ${rh_sso_auth_url}/realms/${rh_sso_rhpam_realm}/protocol/openid-connect/token) | sed 's/.*access_token":"//g' | sed 's/".*//g'
}

function get_sso_token_public() {
  echo $(curl -s --data "grant_type=password&client_id=${1}&username=${rh_sso_rhpam_username}&password=${rh_sso_rhpam_password}" \
  ${rh_sso_auth_url}/realms/${rh_sso_rhpam_realm}/protocol/openid-connect/token) | sed 's/.*access_token":"//g' | sed 's/".*//g'
}

function get_params_by_path() {
  aws ssm get-parameters-by-path --path ${1} --recursive --query Parameters
}

function get_from_params_by_name() {
  jq ".[] | select(.Name == \"$2\") | .Value" <<< $1 | tr -d '"'
}

if [[ ($1 == "--help") || $1 == "-h" || $# -ne 1 ]]; then
  show_usage
  exit 0
fi

is_awsEC2="$(is_awsEC2)"
if [ "${is_awsEC2}" == "no" ]; then
  echo "**Note**: This runs only on AWS EC2 instances"
  exit -1
fi

SERVICE=${1}
params_path=/temenos/rhpam/prod
params=$(get_params_by_path $params_path)

rhpam_database_host=$(get_from_params_by_name "$params" $params_path/database/host)
rhpam_database_port=$(get_from_params_by_name "$params" $params_path/database/port)
rhpam_database_username=$(get_from_params_by_name "$params" $params_path/database/username)
rhpam_database_password=$(get_from_params_by_name "$params" $params_path/database/password)
rhpam_database_url=jdbc:postgresql://$rhpam_database_host:$rhpam_database_port

rh_sso_auth_host=$(get_from_params_by_name "$params" $params_path/rh-sso/host)
rh_sso_auth_port=$(get_from_params_by_name "$params" $params_path/rh-sso/port)
rh_sso_rhpam_username=$(get_from_params_by_name "$params" $params_path/rh-sso/username)
rh_sso_rhpam_password=$(get_from_params_by_name "$params" $params_path/rh-sso/password)
rh_sso_rhpam_realm=$(get_from_params_by_name "$params" $params_path/rh-sso/realm)
rh_sso_auth_url=http://$rh_sso_auth_host:$rh_sso_auth_port/auth

business_central_host=$(get_from_params_by_name "$params" $params_path/business-central/host)
business_central_port=$(get_from_params_by_name "$params" $params_path/business-central/port)
business_central_client_secret=$(get_from_params_by_name "$params" $params_path/rh-sso/secrets/business-central)

kie_server_client_secret=$(get_from_params_by_name "$params" $params_path/rh-sso/secrets/kie-server)

smart_router_host=$(get_from_params_by_name "$params" $params_path/smart-router/host)
smart_router_port=$(get_from_params_by_name "$params" $params_path/smart-router/port)
smart_router_secret=$(get_from_params_by_name "$params" $params_path/rh-sso/secrets/smart-router)

private_ip=$(get_private_ip)
public_ip=$(get_public_ip)

echo "Private IP is $private_ip"
echo "Public IP is $public_ip"

case $SERVICE in
'rh-sso')
  /opt/rh-sso-7.4/bin/standalone.sh -c standalone.xml -b ${private_ip}\
    -Drhpam.database.url=${rhpam_database_url} -Drhpam.database.username=${rhpam_database_username}\
    -Drhpam.database.password=${rhpam_database_password}
  ;;
'business-central')
  #sso_token="$(get_sso_token business-central $business_central_client_secret)"
  sso_token="$(get_sso_token_public kie-remote)"
  /opt/EAP-7.3.0/bin/standalone.sh -c standalone-full.xml -b ${private_ip}\
    -Drhpam.sso.token=${sso_token} -Drhpam.sso.auth.url=${rh_sso_auth_url}\
    -Dbusiness.central.client.secret=${business_central_client_secret}
  ;;
'kie-server')
  #sso_token="$(get_sso_token kie-server $kie_server_client_secret)"
  sso_token="$(get_sso_token_public kie-remote)"
  /opt/EAP-7.3.0/bin/standalone.sh -c standalone-full.xml -b ${private_ip}\
    -Drhpam.database.url=${rhpam_database_url} -Drhpam.database.username=${rhpam_database_username}\
    -Drhpam.database.password=${rhpam_database_password} -Drhpam.sso.token=${sso_token}\
    -Drhpam.sso.token=${sso_token} -Drhpam.sso.auth.url=${rh_sso_auth_url}\
    -Dkie.server.client.secret=${kie_server_client_secret}\
    -Dsmart.router.host=${smart_router_host} -Dsmart.router.port=${smart_router_port}\
    -Dbusiness.central.host=${business_central_host} -Dbusiness.central.port=${business_central_port}\
    -Dpublic.ip=${public_ip}
  ;;
'smart-router')
  #sso_token="$(get_sso_token smart-router $smart_router_secret)"
  sso_token="$(get_sso_token_public kie-remote)"
  java \
    -Dorg.kie.server.router.host=${private_ip} \
    -Dorg.kie.server.router.port=${smart_router_port} \
    -Dorg.kie.server.controller=http://${business_central_host}:${business_central_port}/business-central/rest/controller \
    -Dorg.kie.server.controller.token=${sso_token} \
    -Dorg.kie.server.router.config.watcher.enabled=true \
    -Dorg.kie.server.router.repo=/opt/smartrouter/repo \
    -jar /opt/smartrouter/rhpam-7.11.1-smart-router.jar
  ;;

*)
  echo "Unmanaged service $SERVICE"
  exit -1
  ;;
esac
