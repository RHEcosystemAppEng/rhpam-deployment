#!/usr/bin/bash

show_usage() {
	echo "Script creating AWS environment for the Temenos project"
	echo "-------------------------------------------------------"
	echo "Usage: $0 -h/--help"
	echo "Usage: $0"
	echo "Usage: $0 --project_name <project name> --vpc_cidr <vpc_cidr> --start_cidr <start_cidr> --avail_zones <min_2_az>"
	echo ""
	echo "Example: $0 --project_name \"Temenos RHPAM\" --vpc_cidr 10.0.0.0/16 --start_cidr 10.0.1.0/24 --avail_zones \"us-east-1a,us-east-1b\""
	echo ""
	echo "** please note the \'start_cidr\', this script will increment the third part of the required block."
	echo "** for the example above this script will create:"
	echo "**     in \'us-east-1a\' a \'10.0.1.0/24\' public subnet and a \'10.0.2.0/24\' private subnet"
	echo "**     in \'us-east-1b\' a \'10.0.3.0/24\' public subnet and a \'10.0.4.0/24\' private subnet"
	echo ""
	echo "** requires aws cli to be installed"
	echo "** https://aws.amazon.com/cli/"
	echo ""
	echo "** availability zones:"
	echo "** https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions"
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
vpc_cidr=${vpc_cidr:-10.0.0.0/16}
start_cidr=${start_cidr:-10.0.1.0/24}
project_name=${project_name:-Temenos RHPAM}
avail_zones=${avail_zones:-us-east-1a,us-east-1b}

# utility function for incrementing an integer by an integer
increment_by() { echo $(("$1" + "$2")); }

# utility function for incrementing the third part of a cidr block
increment_cidr() {
    read first second third fourth <<<$(sed "s/\./ /g" <<<$1)
    echo "$first.$second.$(increment_by $third $2).$fourth"
}

##############################################
################# Create VPC #################
##############################################
echo "creating a virtual private cloud with cidr block $vpc_cidr..."
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --tag-specifications "ResourceType=vpc, Tags=[{Key=Name, Value=$project_name VPC}]" \
    --query Vpc.VpcId --output text)

echo "created vpc $vpc_id."

##############################################
############### Create Subnets ###############
##############################################
echo ""
echo "creating subnets for vpc $vpc_id..."

increment_sum=0
public_subnets=""
for current_zone in ${avail_zones//,/ } ; do
	current_pub_cidr=$(increment_cidr "$start_cidr" $increment_sum)

	echo "  - creating public subnet with cidr block $current_pub_cidr for zone $current_zone"
	pub_sub=$(aws ec2 create-subnet \
		--vpc-id $vpc_id \
		--cidr-block $current_pub_cidr \
		--availability-zone ${current_zone} \
		--tag-specifications "ResourceType=subnet, Tags=[{Key=Name, Value=$project_name Public Subnet $current_zone}]" \
		--query Subnet.SubnetId --output text)
	(( increment_sum++ ))
	echo "  - created subnet id $pub_sub"
	public_subnets+="$pub_sub,"

	echo "  - modifying public subnet to map as public ip addresses source on launch"
	aws ec2 modify-subnet-attribute --subnet-id $pub_sub --map-public-ip-on-launch > /dev/null

	current_priv_cidr=$(increment_cidr "$start_cidr" $increment_sum)
	echo "  - creating private subnet with cidr block $current_priv_cidr for zone $current_zone"
	priv_sub=$(aws ec2 create-subnet \
		--vpc-id $vpc_id \
		--cidr-block $current_priv_cidr \
		--availability-zone ${current_zone} \
		--tag-specifications "ResourceType=subnet, Tags=[{Key=Name, Value=$project_name Private Subnet $current_zone}]" \
		--query Subnet.SubnetId --output text)
	(( increment_sum++ ))
	echo "  - created subnet id $priv_sub"

done

public_subnets=${public_subnets::-1}
echo "created public and private subnets."

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

echo "created internet gateway $ig_id."

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

for current_subnet in ${public_subnets//,/ } ; do
	echo "  - associating route table $rt_id with public subnet $current_subnet..."
	aws ec2 associate-route-table --subnet-id $current_subnet --route-table-id $rt_id > /dev/null
done

echo "created and associated gateway $rt_id."

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
