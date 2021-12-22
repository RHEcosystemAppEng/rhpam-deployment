#!/bin/bash

source config.properties

function login(){
  ${KCADM_HOME}/kcadm.sh config credentials --server $KEYCLOAK_URL --realm master --user ${KEYCLOAK_ADMIN_USER} --password ${KEYCLOAK_ADMIN_PWD}
}
function createRealm(){
  ${KCADM_HOME}/kcadm.sh create realms -s realm=$1 -s enabled=true -s sslRequired=NONE -o
}
function defineUser(){
  realmName=$1
  count=0
  for userData in $2; do
    if [ $count == 0 ]
    then
      userName=${userData}
    elif [ $count == 1 ]
    then
      userPwd=${userData}
    else
      echo "REALM_NAME $realmName userName $userName userPwd $userPwd userData $userData"
      createUser ${realmName} ${userName} ${userPwd}
      addRealmRoleToUser ${realmName} ${userName} ${userData}
    fi
    count=$((count+1))
  done
}
function createUser(){
  ${KCADM_HOME}/kcadm.sh create users -r $1 -s username=$2 -s enabled=true
  user_json=$("${KCADM_HOME}"/kcadm.sh get users -r $1 -q username=$2)
  user_id=$(echo $user_json | cut -d: -f2 | cut -d, -f1 | tr -d '"' | tr -d ' ')
  ${KCADM_HOME}/kcadm.sh update users/"$user_id"/reset-password -r $1 -s type=password -s value=$3 -s temporary=false -n
}
function createRealmRole(){
  ${KCADM_HOME}/kcadm.sh create roles -r $1 -s name=$2 -s 'description=RHPAM user role'
}
function addRealmRoleToUser(){
  ${KCADM_HOME}/kcadm.sh add-roles -r $1 --uusername $2 --rolename $3
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
  ${KCADM_HOME}/kcadm.sh add-roles -r $1 --uusername $userName --cclientid $3 --rolename $4
}
function createClient(){
  ${KCADM_HOME}/kcadm.sh create clients -r $1 -s clientId=$2 -s enabled=true $3
}

