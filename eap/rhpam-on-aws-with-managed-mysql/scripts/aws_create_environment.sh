#!/usr/bin/bash

show_usage() {
	echo "Script creating AWS environment for the Temenos project"
	echo "-------------------------------------------------------"
	echo "Usage: $0 -h/--help"
	echo "Usage: $0 --db_instance_cls <db_instance_cls> --ec2_instance_type <ec2_instance_type> --key_pair_name <key_pair_name>"
	echo "Usage: $0 --db_instance_cls <db_instance_cls> --ec2_instance_type <ec2_instance_type> --key_pair_name <key_pair_name> --project_name <project name>  --vpc_cidr <vpc_cidr> --start_cidr <start_cidr> --border_group <border_group>"
	echo ""
	echo "Example: $0 --db_instance_cls \"db.t2.micro\" --ec2_instance_type \"t2.medium\" --key_pair_name \"my-key-pair\""
	echo "Example: $0 --db_instance_cls \"db.t2.micro\" --ec2_instance_type \"t2.medium\" --key_pair_name \"my-key-pair\" --project_name \"Temenos RHPAM\" --vpc_cidr 10.0.0.0/16 --start_cidr 10.0.1.0/24 --border_group us-east-1 --db_instance_cls \"db.t2.micro\""
	echo ""
	echo "** please note the \'start_cidr\', this script will increment the third octet of the required block."
	echo "** for both of the examples above this script will create (db require two availibility zones):"
	echo "**     a \'10.0.1.0/24\' public subnet in \'us-east-1a\',"
	echo "**     a \'10.0.2.0/24\' private subnet in \'us-east-1b\',"
	echo "**     a \'10.0.3.0/24\' private subnet in \'us-east-1c\',"
	echo ""
	echo "** Tip-1: use \'--unmanaged_db\' to skip creation of managed db an validation of db_instance_cls"
	echo "** Tip-2: use \'--db_master_username\' and \'db_master_password\' to set the db instance credentials"
	echo ""
	echo "** requires aws cli to be installed"
	echo "** https://aws.amazon.com/cli/"
	echo ""
	echo "** regions:"
	echo "** https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions"
	echo ""
	echo "** explore zones:"
	echo "** https://aws.amazon.com/about-aws/global-infrastructure/regions_az/"
	echo ""
	echo "** db instance classes:"
	echo "** https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html"
	echo ""
	echo "** ec2 instance types:"
	echo "** https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html"
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
		if [ $param = "unmanaged_db" ]; then
			declare $param="true"
		else
			declare $param="$2"
		fi
	fi
	shift
done

# default named parameters
vpc_cidr=${vpc_cidr:-10.0.0.0/16}
start_cidr=${start_cidr:-10.0.1.0/24}
project_name=${project_name:-Temenos RHPAM}
border_group=${border_group:-us-east-1}
unmanaged_db=${unmanaged_db:-false}
db_master_username=${db_master_username:-rhadmin}
db_master_password=${db_master_password:-redhat123#}

# create border group availability zones
azone_a=$border_group"a"
azone_b=$border_group"b"
azone_c=$border_group"c"

# in managed db mode, db_instance_cls is required
if [ "$unmanaged_db" = "false" ] && [ -z $db_instance_cls ]; then
	show_usage
	exit 1
fi

# an ec2 instance type and the key-pair name are required
if [ -z $ec2_instance_type ] || [ -z $key_pair_name ]; then
	show_usage
	exit 1
fi

# utility function for incrementing an integer by an integer
increment_by() { echo $(("$1" + "$2")); }

# utility function for incrementing the third octet of a cidr block
increment_cidr() {
    read first second third fourth <<<$(sed "s/\./ /g" <<<$1)
    echo "$first.$second.$(increment_by $third $2).$fourth"
}

##############################################
############ Allocate Elastic IP #############
##############################################
echo ""
echo "allocating an elastic IP in $border_group..."
allocation_id=$(aws ec2 allocate-address \
    --network-border-group $border_group \
	--domain vpc \
    --tag-specifications "ResourceType=elastic-ip, Tags=[{Key=Name, Value=$project_name NAT-GW Elastic IP}]" \
    --query AllocationId --output text)

if [ $? -ne 0 ]; then
	echo "failed to allocate elastic IP"
	exit 1
fi

echo "allocated elastic IP $allocation_id."
##############################################
################# Create VPC #################
##############################################
sleep 1
echo ""
echo "creating a virtual private cloud with cidr $vpc_cidr..."
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --tag-specifications "ResourceType=vpc, Tags=[{Key=Name, Value=$project_name VPC}]" \
    --query Vpc.VpcId --output text)

if [ $? -ne 0 ]; then
	echo "failed to create vpc"
	exit 1
fi

echo "  - enabling dns hostnaming for new vpc"
aws ec2 modify-vpc-attribute \
    --vpc-id $vpc_id \
	--enable-dns-hostnames

if [ $? -ne 0 ]; then
	echo "failed to enable dns hostnaming for new vpc"
	exit 1
fi

echo "created vpc $vpc_id."
##############################################
############### Create Subnets ###############
##############################################
sleep 1
echo ""
echo "creating subnets for $vpc_id..."

echo "  - creating a public subnet $start_cidr for zone $azone_a"
pub_sub=$(aws ec2 create-subnet \
	--vpc-id $vpc_id \
	--cidr-block $start_cidr \
	--availability-zone $azone_a \
	--tag-specifications "ResourceType=subnet, Tags=[{Key=Name, Value=$project_name Public Subnet $azone_a}]" \
	--query Subnet.SubnetId --output text)

if [ $? -ne 0 ]; then
	echo "failed to create public subnet"
	exit 1
fi

echo "  - created public subnet $pub_sub."

increment_sum=1
# aggregate private subnets
private_subnets=""
for current_zone in $azone_b $azone_c ; do
	current_cidr=$(increment_cidr "$start_cidr" $increment_sum)

	echo "  - creating a private subnet $current_cidr for zone $current_zone"
	current_priv_sub=$(aws ec2 create-subnet \
		--vpc-id $vpc_id \
		--cidr-block $current_cidr \
		--availability-zone ${current_zone} \
		--tag-specifications "ResourceType=subnet, Tags=[{Key=Name, Value=$project_name Private Subnet $current_zone}]" \
		--query Subnet.SubnetId --output text)
	(( increment_sum++ ))

	if [ $? -ne 0 ]; then
		echo "failed to create private subnet"
		exit 1
	fi

	echo "  - created private subnet $current_priv_sub."
	private_subnets+="$current_priv_sub,"
done
# clean last ',' in subnets aggregation
private_subnets=${private_subnets::-1}

echo "created subnets."
##############################################
############# Create NAT Gateway #############
##############################################
sleep 1
echo ""
echo "creating a nat gateway with $allocation_id for $pub_sub..."
ng_id=$(aws ec2 create-nat-gateway \
    --allocation-id $allocation_id \
    --subnet-id $pub_sub \
    --tag-specifications "ResourceType=natgateway, Tags=[{Key=Name, Value=$project_name NAT Gateway}]" \
    --query NatGateway.NatGatewayId --output text)

if [ $? -ne 0 ]; then
	echo "failed to create nat gateway"
	exit 1
fi

echo "created nat gateway $ng_id."
##############################################
########## Create Internet Gateway ###########
##############################################
sleep 1
echo ""
echo "creating an internet gateway..."
ig_id=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway, Tags=[{Key=Name, Value=$project_name Internet Gateway}]" \
    --query InternetGateway.InternetGatewayId --output text)

if [ $? -ne 0 ]; then
	echo "failed to create internet gateway"
	exit 1
fi

echo "  - attaching internet gateway to vpc $vpc_id..."
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $ig_id > /dev/null

if [ $? -ne 0 ]; then
	echo "failed to attach internet gateway to vpc"
	exit 1
fi

echo "created internet gateway $ig_id."
##############################################
############ Create Route Tables #############
##############################################
sleep 1
echo ""
echo "creating route tables for $vpc_id..."
echo "  - creating route table for the nat gateway..."
nrt_id=$(aws ec2 create-route-table \
    --vpc-id $vpc_id \
    --tag-specifications "ResourceType=route-table, Tags=[{Key=Name, Value=$project_name NAT Route Table}]" \
    --query RouteTable.RouteTableId --output text)

if [ $? -ne 0 ]; then
	echo "failed to create route table for nat gateway"
	exit 1
fi

echo "  - created route table $nrt_id."
echo "  - creating a 0.0.0.0/0 rule in the nat route table for $ng_id..."
aws ec2 create-route \
	--route-table-id $nrt_id \
	--destination-cidr-block 0.0.0.0/0 \
	--nat-gateway-id $ng_id \
	> /dev/null

if [ $? -ne 0 ]; then
	echo "failed to create route table rule in $nrt_id"
	exit 1
fi

echo "  - retrieving default route table for $vpc_id..."

read def_ass_id def_rt_id <<<$(aws ec2 describe-route-tables \
    --filters "[{\"Name\": \"association.main\", \"Values\": [\"true\"]}, {\"Name\": \"vpc-id\", \"Values\": [\"$vpc_id\"]}]" \
    --query RouteTables[].Associations[].[RouteTableAssociationId,RouteTableId] --output text)

if [ $? -ne 0 ]; then
	echo "failed to retrieve the default route table for $vpc_id"
	exit 1
fi

echo "  - found default table $def_rt_id, replacing with nat table $nrt_id..."
aws ec2 replace-route-table-association \
    --association-id $def_ass_id \
    --route-table-id $nrt_id \
    > /dev/null

if [ $? -ne 0 ]; then
	echo "failed to replace the default route table for $vpc_id"
	exit 1
fi

echo "  - replaced default route table, deleting original one..."
aws ec2 delete-route-table --route-table-id $def_rt_id

if [ $? -ne 0 ]; then
	echo "failed to delete the original default route table for $vpc_id"
	exit 1
fi

echo "  - deleted default route table $def_rt_id."
echo "  - creating route table for the internet gateway..."
irt_id=$(aws ec2 create-route-table \
    --vpc-id $vpc_id \
    --tag-specifications "ResourceType=route-table, Tags=[{Key=Name, Value=$project_name Internet Route Table}]" \
    --query RouteTable.RouteTableId --output text)

if [ $? -ne 0 ]; then
	echo "failed to create route table for internet gateway"
	exit 1
fi

echo "  - created route table $irt_id."
echo "  - creating a 0.0.0.0/0 rule in the internet route table for $ig_id..."
aws ec2 create-route \
	--route-table-id $irt_id \
	--destination-cidr-block 0.0.0.0/0 \
	--gateway-id $ig_id \
	> /dev/null

echo "  - associating the internet route table with the public subnet $pub_sub..."
aws ec2 associate-route-table \
	--subnet-id $pub_sub \
	--route-table-id $irt_id \
	> /dev/null

if [ $? -ne 0 ]; then
	echo "failed to associate the internet route table with the public subnet"
	exit 1
fi

echo "created and configured the route tables."
##############################################
######### Create Security Groups #############
##############################################
sleep 1
echo ""
echo "creating security groups for $vpc_id..."

echo "  - creating rhpam jboss frontend group..."
front_grp_id=$(aws ec2 create-security-group \
    --group-name rhpam-jboss-front \
    --description "$project_name JBoss Front Security Group" \
    --vpc-id $vpc_id \
    --tag-specifications "ResourceType=security-group, Tags=[{Key=Name, Value=$project_name JBoss Front Security Group}]" \
    --query GroupId --output text)

if [ $? -ne 0 ]; then
	echo "failed to create front security group"
	exit 1
fi

echo "    - adding inbound rule TCP8080..."
aws ec2 authorize-security-group-ingress \
    --group-id $front_grp_id \
    --protocol tcp \
    --port 8080 \
    --cidr "0.0.0.0/0" \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=Business Central Http}]' \
    > /dev/null

if [ $? -ne 0 ]; then
	echo "failed to add inbound rule for TCP-8080 to $front_grp_id"
	exit 1
fi

echo "    - adding inbound rule TCP8443..."
aws ec2 authorize-security-group-ingress \
    --group-id $front_grp_id \
    --protocol tcp \
    --port 8443 \
    --cidr "0.0.0.0/0" \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=Business Central Https}]' \
    > /dev/null

if [ $? -ne 0 ]; then
	echo "failed to add inbound rule for TCP-8443 to $front_grp_id"
	exit 1
fi

echo "    - adding inbound rule TCP9990..."
aws ec2 authorize-security-group-ingress \
    --group-id $front_grp_id \
    --protocol tcp \
    --port 9990 \
    --cidr "0.0.0.0/0"  \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=Administration GUI}]' \
    > /dev/null

if [ $? -ne 0 ]; then
	echo "failed to add inbound rule for TCP-9990 to $front_grp_id"
	exit 1
fi

echo "    - adding inbound rule TCP22..."
aws ec2 authorize-security-group-ingress \
    --group-id $front_grp_id \
    --protocol tcp \
    --port 22 \
    --cidr "0.0.0.0/0" \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=SSH Connection}]' \
    > /dev/null

if [ $? -ne 0 ]; then
	echo "failed to add inbound rule for TCP-22 to $front_grp_id"
	exit 1
fi

echo "  - creating rhpam mysql backend group..."
back_grp_id=$(aws ec2 create-security-group \
    --group-name rhpam-mysql-back \
    --description "$project_name MySQL Back Security Group" \
    --vpc-id $vpc_id \
    --tag-specifications "ResourceType=security-group, Tags=[{Key=Name, Value=$project_name MySQL Back Security Group}]" \
    --query GroupId --output text)

if [ $? -ne 0 ]; then
	echo "failed to create back security group"
	exit 1
fi

echo "    - adding inbound rule TCP3306..."
aws ec2 authorize-security-group-ingress \
    --group-id $back_grp_id \
    --protocol tcp \
    --port 3306 \
    --source-group $front_grp_id \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=MySQL Connection}]' \
    > /dev/null

if [ $? -ne 0 ]; then
	echo "failed to add inbound rule for TCP-3306 to $back_grp_id"
	exit 1
fi

echo "    - adding inbound rule TCP22..."
aws ec2 authorize-security-group-ingress \
    --group-id $back_grp_id \
    --protocol tcp \
    --port 22 \
    --source-group $front_grp_id \
    --tag-specifications 'ResourceType=security-group-rule, Tags=[{Key=Name, Value=SSH Connection}]' \
    > /dev/null

if [ $? -ne 0 ]; then
	echo "failed to add inbound rule for TCP-22 to $back_grp_id"
	exit 1
fi

echo "created frontend group $front_grp_id and backend group $back_grp_id."
##############################################
####### Create Managed RDS Instance ##########
##############################################
# unamanged_db is a way to opt-out of the managed db in case an unmanaged one is needed
if [ "$unmanaged_db" = false ] ; then
	##############################################
	########## Create DB Subnet Group ############
	##############################################
	sleep 1
	echo ""
	echo "creating an db subnet group..."
	aws rds create-db-subnet-group \
		--db-subnet-group-name rhpam-mysql-subnet-group \
		--db-subnet-group-description "$project_name MySQL Subnet Group" \
		--subnet-ids "[\"$(sed 's/,/","/g' <<< $private_subnets)\"]" \
		--tags "[{\"Key\": \"Name\", \"Value\": \"$project_name MySQL Subnet Group\"}]" \
		> /dev/null

	if [ $? -ne 0 ]; then
		echo "failed to create the db subnet group"
	fi

	echo "created db subnet group."
	##############################################
	############# Create MySQL DB ################
	##############################################
	sleep 1
	echo ""
	echo "creating mysql db rds instance of class $db_instance_cls..."
	aws rds create-db-instance \
		--db-name jbpm \
		--db-instance-identifier rhpam-mysql-db \
		--db-instance-class $db_instance_cls \
		--engine mysql \
		--engine-version 8.0.25 \
		--master-username $db_master_username \
		--master-user-password $db_master_password \
		--vpc-security-group-ids $back_grp_id \
		--db-subnet-group-name rhpam-mysql-subnet-group \
		--no-publicly-accessible \
		--no-auto-minor-version-upgrade \
		--tags "[{\"Key\": \"Name\", \"Value\": \"$project_name MySQL DB\"}]" \
		--enable-cloudwatch-logs-exports error \
		--allocated-storage 20 \
		> /dev/null

	if [ $? -ne 0 ]; then
		echo "failed to create the db instance"
	fi

	echo "created db instance."
fi

##############################################
######### Create EC2 RHEL Instance ###########
##############################################
sleep 1
echo ""
echo "creating rhel ec2 instance of type $ec2_instance_type..."
ec2_id=$(aws ec2 run-instances \
    --image-id ami-0b0af3577fe5e3532 \
    --instance-type $ec2_instance_type \
	--subnet-id $pub_sub \
    --key-name $key_pair_name \
    --security-group-ids $front_grp_id \
    --tag-specifications "ResourceType=instance, Tags=[{Key=Name, Value=Temenos RHPAM JBoss}]" \
    --associate-public-ip-address \
	--query Instances[].InstanceId --output text)

if [ $? -ne 0 ]; then
	echo "failed to create rhel ec2 instance"
fi

echo "created ec2 instance $ec2_id."
echo ""
echo "** tip: run the following command to get the ec2 instace public name/ip once it's up:"
echo "** aws ec2 describe-instances --instance-ids $ec2_id --query Reservations[].Instances[].[PublicDnsName,PublicIpAddress]"

echo ""
echo "Done!"
