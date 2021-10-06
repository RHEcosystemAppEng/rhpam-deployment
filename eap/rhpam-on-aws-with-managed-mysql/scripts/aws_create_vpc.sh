#!/usr/bin/bash

show_usage() {
	echo "Script creating AWS EC2 Virtual Private Cloud for the Temenos project"
	echo "----------------------------------------------------------------------"
	echo "Usage: $0 -h/--help"
	echo "Usage: $0"
	echo "Usage: $0 --project_name <project name> --vpc_cidr <vpc_cidr> --pub_cidr <pub_cidr> --priv_cidr <priv_cidr>"
	echo ""
	echo "Example: $0 --project_name \"Temenos RHPAM\" --vpc_cidr 10.0.0.0/16 --pub_cidr 10.0.1.0/24 --priv_cidr 10.0.0.0/24"
	echo ""
	echo "Tip: add --verbose"
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
		if [ "$param" = "verbose" ]; then
			declare $param=true
		else
			declare $param="$2"
		fi
	fi
	shift
done

# default named parameters
vpc_cidr=${vpc_cidr:-10.0.0.0/16}
pub_cidr=${pub_cidr:-10.0.1.0/24}
priv_cidr=${priv_cidr:-10.0.0.0/24}
verbose=${verbose:-false}
project_name=${project_name:-Temenos RHPAM}


##############################################
################# Create VPC #################
##############################################
echo "creating a virtual private cloud with cidr block $vpc_cidr..."
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --tag-specifications "ResourceType=vpc, Tags=[{Key=Name, Value=$project_name VPC}]" \
    --query Vpc.VpcId --output text)

echo "created vpc $vpc_id ."
if [ "$verbose" = true ]; then
	echo ""
	echo $(aws ec2 describe-vpcs --vpc-ids $vpc_id)
fi

##############################################
############### Create Subnets ###############
##############################################
echo ""
echo "creating subnets for vpc $vpc_id..."

echo "  - creating public subnet with cidr block $pub_cidr"
pub_sub=$(aws ec2 create-subnet \
    --vpc-id $vpc_id \
    --cidr-block $pub_cidr \
    --tag-specifications "ResourceType=subnet, Tags=[{Key=Name, Value=$project_name Public Subnet}]" \
    --query Subnet.SubnetId --output text)

echo "  - modifying public subnet to map as public ip addresses source on launch"
aws ec2 modify-subnet-attribute --subnet-id $pub_sub --map-public-ip-on-launch > /dev/null

echo "  - creating private subnet with cidr block $priv_cidr"
priv_sub=$(aws ec2 create-subnet \
    --vpc-id $vpc_id \
    --cidr-block $priv_cidr \
    --tag-specifications "ResourceType=subnet, Tags=[{Key=Name, Value=$project_name Private Subnet}]" \
    --query Subnet.SubnetId --output text)

echo "created public subnet $pub_sub and private subnet $priv_sub ."
if [ "$verbose" = true ]; then
	echo ""
	echo $(aws ec2 describe-subnets --subnet-ids $pub_sub $priv_sub)
fi

##############################################
########## Create Internet Gateway ###########
##############################################
echo ""
echo "creating an internet gateway..."
ig_id=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway, Tags=[{Key=Name, Value=$project_name Internet Gateway}]" \
    --query InternetGateway.InternetGatewayId --output text)

echo "  - attaching internet gateway to vpc $vpc_id..."
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $ig_id > /dev/null

echo "created internet gateway $ig_id ."
if [ "$verbose" = true ]; then
	echo ""
	echo $(aws ec2 describe-internet-gateways --internet-gateway-ids $ig_id)
fi

##############################################
############# Create Route Table #############
##############################################
echo ""
echo "creating a route table for vpc $vpc_id..."
rt_id=$(aws ec2 create-route-table \
    --vpc-id $vpc_id \
    --tag-specifications "ResourceType=route-table, Tags=[{Key=Name, Value=$project_name Route Table}]" \
    --query RouteTable.RouteTableId --output text)

echo "  - creating a rule in route table $rt_id with CIDR 0.0.0.0/0..."
aws ec2 create-route --route-table-id $rt_id --destination-cidr-block 0.0.0.0/0 --gateway-id $ig_id > /dev/null

echo "  - associating route table $rt_id with public subnet $pub_sub..."
aws ec2 associate-route-table --subnet-id $pub_sub --route-table-id $rt_id > /dev/null

echo "Created and associated gateway $rt_id ."
if [ "$verbose" = true ]; then
	echo ""
	echo $(aws ec2 describe-route-tables --route-table-id $rt_id)
fi

echo ""
echo "Done!"
