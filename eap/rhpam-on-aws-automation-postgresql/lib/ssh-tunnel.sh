#!/bin/bash

function usage() {
  echo "Usage: $0 [-h] [-k] -l <local port> [-s <SSH pem file>] [-u <SSH user>] [-t <target host/IP>] [-p <target port>] [-n]"
  echo "   -h to print this message"
  echo "   -k to kill an existing SSH tunnel"
  echo "   -n to use current user instead of sudo (no-sudo)"
  exit 1;
}

function killTunnel() {
  [[ "${useSudo}" = true ]] && cmd="sudo kill" || cmd="kill"
  echo "Deleting SSH tunnel at localhost:${localPort}. Command is ${cmd}"
  ps -ef | grep "ssh -i.*${localPort}" | grep -v grep | awk '{print $2}' | xargs $cmd
}

function cleanKnownHosts(){
  [[ "${useSudo}" = true ]] && cmd="sudo sed" || cmd="sed"
  echo "Removing entry from ~/.ssh/known_hosts for localhost:${localPort}. Command is ${cmd}"
  ${cmd} -i -e "/^\[localhost\]:${localPort} .*$/d" ~/.ssh/known_hosts
}

function createSSHTunnel(){
    [[ "${useSudo}" = true ]] && cmd="sudo ssh" || cmd="ssh"
    echo "Creating SSH tunnel for ${sshUser} using ${sshPemFile} to ${remoteHost}:${remotePort} on localhost:${localPort}. Command is ${cmd}"
    ${cmd} -i ${sshPemFile} ${sshUser}@18.197.92.7 -N -f  -L ${localPort}:${remoteHost}:${remotePort}
}

option='create'
unset localPort
unset sshPemFile
unset sshUser
unset remoteHost
remotePort=22
useSudo=true
while getopts "hkl:s:u:t:p:n" o; do
  case "${o}" in
    k)  option='kill';;
    l)  localPort=${OPTARG};;
    s)  sshPemFile=${OPTARG};;
    u)  sshUser=${OPTARG};;
    t)  remoteHost=${OPTARG};;
    p)  remotePort=${OPTARG};;
    n)  useSudo=false;;
    h|?)  echo "Unknown option ${o}"
        usage ;;
  esac
done

#echo "$option $localPort $sshPemFile $sshUser $remoteHost $remotePort $useSudo"
if [ "${option}" == 'create' ]; then
  if [ -z "${localPort}" ] || [ -z "${sshPemFile}" ] || [ -z "${sshUser}" ] || [ -z "${remoteHost}" ]; then
    echo "Missing expected parameters to create a new SSH tunnel"
    usage
  else
    killTunnel
    cleanKnownHosts
    createSSHTunnel
  fi
else
  if [ -z "${localPort}" ]; then
    echo "Missing expected parameters to kill existing SSH tunnel"
    usage
  else
    killTunnel
    cleanKnownHosts
  fi
fi
