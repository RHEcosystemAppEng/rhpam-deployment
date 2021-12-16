#!/bin/bash

source $(dirname "$0")/runtime.properties

function unmount(){
    echo "Unmounting EFS from ${GIT_HOME}"
    sudo umount ${GIT_HOME}
    # yum install -y lsof
    #  lsof | grep '/opt/rhpam/git'
    # kill -9 <PID>
    sudo sed -i "/^.*${GIT_HOME//\//\\/}.*$/d" /etc/fstab
}

function installEfsUtils(){
  if [ $(sudo yum list installed amazon-efs-utils.noarch > /dev/null 2>&1; echo $?) -ne 0 ]; then
    echo "Installing amazon-efs-utils"
    sudo yum -y install git
    sudo yum -y install rpm-build
    cd /tmp
    git clone https://github.com/aws/efs-utils
    cd /tmp/efs-utils
    sudo yum -y install make
    sudo make rpm
    sudo yum -y install ./build/amazon-efs-utils*rpm
  else
    echo "Package amazon-efs-utils.noarch is already installed"
  fi
}

function mount(){
  sudo mkdir -p /opt/rhpam/git
  echo "Mounting persistent EFS to /opt/rhpam/git"
  sudo --preserve-env=EFS_IP --preserve-env=EFS_ROOT_PATH --preserve-env=GIT_HOME --preserve-env=EFS_OPTIONS \
    sh -c "echo '${EFS_IP}:${EFS_ROOT_PATH} ${GIT_HOME} nfs4 ${EFS_OPTIONS}' >> /etc/fstab"
  sudo mount -av
  df -T -h
  sudo rm -rf /tmp/efs-utils
}

if [ "$1" == "-u" ]; then
  unmount
else
  unmount
  installEfsUtils
  mount
fi
