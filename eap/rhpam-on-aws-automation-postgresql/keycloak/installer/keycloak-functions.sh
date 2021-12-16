#!/bin/bash

source keycloak.properties
source common-functions.sh

function installKeycloak(){
  headerLog "installKeycloak"
  execute "sudo rm -rf ${KEYCLOAK_HOME}; sudo mkdir ${KEYCLOAK_HOME}"
  execute "sudo cp /tmp/${KEYCLOAK_INSTALLER} ${KEYCLOAK_HOME}"
  execute "cd ${KEYCLOAK_HOME}"
  execute "sudo tar -xvzf ${KEYCLOAK_INSTALLER} --strip-components=1"
  execute "sudo rm ${KEYCLOAK_INSTALLER}"
  startServer
  execute "sudo ${KEYCLOAK_HOME}/bin/add-user-keycloak.sh -r master -u $KEYCLOAK_ADMIN_USER -p $KEYCLOAK_ADMIN_PWD"
  stopServer
}

function login(){
  KEYCLOAK_URL_LOCAL="http://localhost:$KEYCLOAK_SERVER_PORT/auth"
  ${KEYCLOAK_HOME}/bin/kcadm.sh config credentials --server $KEYCLOAK_URL_LOCAL --realm master --user ${KEYCLOAK_ADMIN_USER} --password ${KEYCLOAK_ADMIN_PWD}
}
function createRealm(){
  ${KEYCLOAK_HOME}/bin/kcadm.sh create realms -s realm=$1 -s enabled=true -s sslRequired=NONE -o
}
function defineUser(){
  count=0
  for userData in $1; do
    if [ $count == 0 ]
    then
      userName=${userData}
    elif [ $count == 1 ]
    then
      userPwd=${userData}
    else
      echo "REALM_NAME $REALM_NAME userName $userName userPwd $userPwd userData $userData"
      createUser ${REALM_NAME} ${userName} ${userPwd}
      addRealmRoleToUser ${REALM_NAME} ${userName} ${userData}
    fi
    count=$((count+1))
  done
}
function createUser(){
  ${KEYCLOAK_HOME}/bin/kcadm.sh create users -r $1 -s username=$2 -s enabled=true
  user_json=$("${KEYCLOAK_HOME}"/bin/kcadm.sh get users -r $1 -q username=$2)
  user_id=$(echo $user_json | cut -d: -f2 | cut -d, -f1 | tr -d '"' | tr -d ' ')
  ${KEYCLOAK_HOME}/bin/kcadm.sh update users/"$user_id"/reset-password -r $1 -s type=password -s value=$3 -s temporary=false -n
}
function createRealmRole(){
  ${KEYCLOAK_HOME}/bin/kcadm.sh create roles -r $1 -s name=$2 -s 'description=RHPAM user role'
}
function addRealmRoleToUser(){
  ${KEYCLOAK_HOME}/bin/kcadm.sh add-roles -r $1 --uusername $2 --rolename $3
}
function addClientRoleToUser(){
  count=0
  userName=""
  for userData in $2; do
      if [ $count == 0 ]
      then
        userName=${userData}
      fi
      count=$((count+1))
    done
  ${KEYCLOAK_HOME}/bin/kcadm.sh add-roles -r $1 --uusername $userName --cclientid $3 --rolename $4
}
function createClient(){
  ${KEYCLOAK_HOME}/bin/kcadm.sh create clients -r $1 -s clientId=$2 -s enabled=true $3
}

