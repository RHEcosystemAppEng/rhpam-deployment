#!/usr/bin/bash

show_usage() {
	echo "Script creating AWS EC2 Security Groups for the Temenos project"
	echo "---------------------------------------------------------------"
	echo "Usage: $0 -h/--help"
    echo "Usage: $0"
	echo "Usage: $0 --vpc_name <vpc_name> --project_name <project name>"
	echo ""
	echo "Example: $0 --vpc_name \"Temenos RHPAM VPC\" --project_name \"Temenos RHPAM\""
	echo ""
	echo "** requires aws cli to be installed"
	echo "** https://aws.amazon.com/cli/"
}

# show usage if asked for help
if [[ ($1 == "--help") || $1 == "-h" ]]; then
	show_usage
	exit 0
fi

# iterate over arguments and create named parameters
while [ $# -gt 0 ]; do
	if [[ $1 == *"--"* ]]; then
		param="${1/--/}"
        declare $param="$2"
	fi
	shift
done

# default named parameters
vpc_name=${vpc_name:-Temenos RHPAM VPC}
project_name=${project_name:-Temenos RHPAM}

##############################################
################ Retrive VPC #################
##############################################
echo "retrieving vpc id with 'Name' tag of $vpc_name..."
vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$vpc_name" --query "Vpcs[*].VpcId" --output text)
echo "found vpc $vpc_id."

##############################################
######### Create Security Groups #############
##############################################
echo ""
echo "creating secutiry groups for vpc $vpc_id..."

echo "  - creating rhpam frontend group..."
front_grp_id=$(aws ec2 create-security-group \
    --group-name rhpam-front \
    --description "$project_name Front" \
    --vpc-id $vpc_id \
    --tag-specifications "ResourceType=security-group, Tags=[{Key=Name, Value=$project_name Front}]" \
    --query GroupId --output text)

echo "    - adding inbound rule TCP8080..."
aws ec2 authorize-security-group-ingress \
    --group-id $front_grp_id \
    --protocol tcp \
    --port 8080 \
    --cidr "0.0.0.0/0" \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=Business Central Http}]' \
    > /dev/null

echo "    - adding inbound rule TCP8443..."
aws ec2 authorize-security-group-ingress \
    --group-id $front_grp_id \
    --protocol tcp \
    --port 8443 \
    --cidr "0.0.0.0/0" \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=Business Central Https}]' \
    > /dev/null

echo "    - adding inbound rule TCP9990..."
aws ec2 authorize-security-group-ingress \
    --group-id $front_grp_id \
    --protocol tcp \
    --port 9990 \
    --cidr "0.0.0.0/0"  \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=Administration GUI}]' \
    > /dev/null

echo "    - adding inbound rule TCP22..."
aws ec2 authorize-security-group-ingress \
    --group-id $front_grp_id \
    --protocol tcp \
    --port 22 \
    --cidr "0.0.0.0/0" \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=SSH Connection}]' \
    > /dev/null


echo "  - creating rhpam mysql backend group..."
back_grp_id=$(aws ec2 create-security-group \
    --group-name rhpam-mysql-back \
    --description "$project_name MySQL Back" \
    --vpc-id $vpc_id \
    --tag-specifications "ResourceType=security-group, Tags=[{Key=Name, Value=$project_name MySQL Back}]" \
    --query GroupId --output text) \
    > /dev/null

echo "    - adding inbound rule TCP3306..."
aws ec2 authorize-security-group-ingress \
    --group-id $back_grp_id \
    --protocol tcp \
    --port 3306 \
    --cidr "0.0.0.0/0" \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=MySQL Connection}]' \
    > /dev/null

echo "    - adding inbound rule TCP22..."
aws ec2 authorize-security-group-ingress \
    --group-id $back_grp_id \
    --protocol tcp \
    --port 22 \
    --cidr "0.0.0.0/0" \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=SSH Connection}]' \
    > /dev/null

echo "created frontend group $front_grp_id and backend group $back_grp_id."

echo ""
echo "Done!"
