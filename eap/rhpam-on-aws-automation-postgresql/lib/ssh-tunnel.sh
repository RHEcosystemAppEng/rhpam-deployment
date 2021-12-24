#!/bin/bash

function usage() {
  echo "Usage: $0 [-h] [-k] -l <local port> [-s <SSH pem file>] [-u <SSH user>] [-t <tunnel host>] [-r <remote host/IP>]"
  echo "   -h to print this message"
  echo "   -k to kill an existing SSH tunnel"
  exit 1;
}

function killTunnel() {
  echo "Deleting SSH tunnel at localhost:${localPort}"
  ps -ef | grep "ssh -i.*${localPort}" | grep -v grep | awk '{print $2}' | xargs sudo kill
}

function cleanKnownHosts(){
  echo "Removing entry from ~/.ssh/known_hosts for localhost:${localPort}"
  sudo sed -i -e "/^\[localhost\]:${localPort} .*$/d" ~/.ssh/known_hosts
}

function createSSHTunnel(){
  echo "Creating SSH tunnel through ${tunnelHost} for ${sshUser}/${sshPemFile} to ${remoteHost}:${remotePort} on localhost:${localPort}"
  sudo ssh -i ${sshPemFile} ${sshUser}@${tunnelHost} -N -f -L ${localPort}:${remoteHost}:${remotePort}
}

option='create'
unset localPort
unset sshPemFile
unset sshUser
unset tunnelHost
unset remoteHost
remotePort=22
while getopts "hkl:s:u:t:r:" o; do
  case "${o}" in
    k)  option='kill';;
    l)  localPort=${OPTARG};;
    s)  sshPemFile=${OPTARG};;
    u)  sshUser=${OPTARG};;
    t)  tunnelHost=${OPTARG};;
    r)  remoteHost=${OPTARG};;
    h|?)  echo "Unknown option ${o}"
        usage ;;
  esac
done

#echo "$option $localPort $sshPemFile $sshUser $tunnelHost $remoteHost $remotePort"
if [ "${option}" == 'create' ]; then
  if [ -z "${localPort}" ] || [ -z "${sshPemFile}" ] || [ -z "${sshUser}" ] || [ -z "${tunnelHost}" ] || [ -z "${remoteHost}" ]; then
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
