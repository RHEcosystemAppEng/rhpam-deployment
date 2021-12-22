#!/bin/bash

source runtime_eip.properties

# Set AWS_ACCESS_KEY, AWS_SECRET_KEY and  AWS_DEFAULT_REGION - if `aws configure` on instance was done - not needed
#export AWS_ACCESS_KEY_ID=""
#export AWS_SECRET_ACCESS_KEY=""
#export AWS_DEFAULT_REGION=""

# pre-allocated EIP - get by tag
if [  "$EIP_TAG_VALUE" == "" ]; then
  echo "eip tag not defined"
  exit
fi
eip_allocation_id=$(aws ec2 describe-tags --filters "Name=value,Values=$EIP_TAG_VALUE" --query "Tags[].ResourceId | [0]")
if [  "$eip_allocation_id" == null ]; then
  echo "eip_allocation_id not found"
  exit
fi
allocated_eip=$(aws ec2 describe-addresses --filters "Name=allocation-id,Values=${eip_allocation_id}" --query "Addresses[].PublicIp | [0]")
# remove the double quotes
allocated_eip=$(echo $allocated_eip | sed 's/^"\|"$//g')

existing_eip=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
echo eip_allocation_id=$eip_allocation_id --- allocated_eip=$allocated_eip --- existing_eip=$existing_eip

if [ "${allocated_eip}" == "${existing_eip}" ]; then
    echo "elastic ip ${existing_eip} is already associated"
    exit
fi

# Get the instance ID of the current instance from its metadata
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "associating pre-allocated eip: ${allocated_eip} with instance id: ${instance_id}"
aws ec2 associate-address --instance-id $instance_id --public-ip $allocated_eip
