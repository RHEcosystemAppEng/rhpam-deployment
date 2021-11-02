# Deploy RHPAM 7.11.1 AWS with a PostgreSQL backend

## Document goal

Walkthrough the installation and deployment of [RHPAM][8] running on [JBoss EAP][9] with a `Smart Router` and  RHSSO[21] on [AWS][0].
Leveraging parameter centralizing, load balancing, auto-scaling, and network segmentation.</br>

[Asana task][24]

## Version matrix

| Component            | Version |
| :---------           | :-----: |
| RHSSO                | 7.4.9   |
| RHPAM                | 7.11.1  |
| JBoss                | 7.3.6   |
| Java                 | 11      |
| PostgreSQL           | 11.13   |
| PostrgeSQL Connector | 42.3.0  |

> Please take a look at [this matrix][18] before attempting to use other versions.

## Regions and Availability Zones

Based on [AWS Documentation][22], a `Region`, also known as a `Network Border` is a physical location around the world where *AWS*
operates data centers.</br>
An `Availability Zone` is a group of one or more data centers with redundant power, networking, and connectivity in a `Region`.

> Each AWS Region consists of multiple, isolated, and physically separate AZs within a geographic area.

The managed services of *AWS* used for this procedure, i.e. *RDS* for hosting the *PostgreSQL* database and *ELB* for load
balancing the requests for *RHSSO*, requires a minimum of **two** availability zones in the same region.</br>
For this procedure, you'll be using `us-east-1` as the region, and `us-east-1a` and `us-east-1b` as the availability zones.

## Instance Types and Classes

For the manages *PostgreSQL RDS Instance*, you can use one of the instance classes listed [here][19], `db.t2.micro` was
used for this runbook creation.

For the various *EC2 Instances*, you can use one of the instance types listed [here][14], `t2.medium` was used for this
runbook creation.

> Please note that *JBoss* requires a minimum of 2 vCPUs and 2 GiB memory.

## Prerequisites

### Prerequisite: Prepare installers

From your local station download the following files:

- [PostgreSQL connector 42.3.0][25]
- [Red Hat Single Sign-On 7.4.0 Server][26]
- [Red Hat Single Sign-On 7.4.0 Client Adapter for EAP 7][26]
- [Red Hat Single Sign-On 7.4.9 Server Patch][27]
- [Red Hat JBoss Enterprise Application Platform 7.3.0 Installer][28]
- [Red Hat JBoss Enterprise Application Platform 7.3 Update 06][29]
- [Red Hat Process Automation Manager 7.11.1 Add-Ons][30]

Extract the last downloaded file `rhpam-7.11.1-add-ons` and grab the following files:

- `rhpam-7.11.1-migration-tool.zip`
- `rhpam-7.11.1-smart-router.jar`

### Prerequisite: Open URLs

Although you can reach everything from the console[1],
Here are the links for the services and components you'll work with:

- [AWS VPC][31] - *Virtual Private Cloud*, *Subnets*, *Route Tables*, *Internet Gateway*, and *NAT Gateway*.
- [AWS RDS][32] - *Database Instance* and *Subnet Groups*.
- [AWS EC2][33] - *EC2 Instances*, *Amazon Machine Images*, *Security Groups*, *Elastic IPs*, *Key Pairs*, *Load Balancer*,
  *Target Groups*, *Launch Configurations*, and *Auto Scaling Groups*.
- [AWS System Manager][34] - *Parameters Store*
- [AWS IAM][35] - *Roles* and *Policies*

### Prerequisite: Prepare a Key-Pair

You'll use *SSH* to connect to the various *EC2* instances, you can create a new *Key-Pair* or import your own [here][23].</br>
You can use the same key for multiple instances.

If you create a new *Key-Pair*,</br>
once created, you will be able to download the private key to your local station.</br>
you might need to set `chmod 400` to the downloaded file.

If you import an existing key,</br>
make sure to paste in the **public** key content and not the private one.

## Create the environment

### Create the Elastic IPs

Create **three** *Elastic IP's* with the following characteristics:

```text
Network Border: us-east-1
Tags: Name=Temenos NAT-GW us-east-1a EIP
```

```text
Network Border: us-east-1
Tags: Name=Temenos Business Central us-east-1b EIP
```

```text
Network Border: us-east-1
Tags: Name=Temenos Smart Router us-east-1b EIP
```

> Note that the *NAT-GW* is planned to be created on the *us-east-1a AZ*, while the *Business Central* and
> *Smart Router* will be on the *use-east-1b AZ*.</br>
> There's no particular reason for that, mainly, you have only one of each, so a load splitting seems like a good idea.

### Create the Policy

Create a policy for allowing read access to the `Parameter Store`,</br>
Add the following `JSON` as the policy configuration, and set the name as `temenos-get-parameters-policy`:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeParameters",
                "ssm:GetParametersByPath",
                "ssm:GetParameter"
            ],
            "Resource": "*"
        }
    ]
}
```

### Create the Role

Create a Role with a `AWS Service Type` for *EC2* use cases.</br>
Attach the `temenos-get-parameters-policy` you created, and set the name as `temenos-ec2-get-parameters-role`.

### Create the VPC

The *Virtual Private Cloud* will be the base of our isolated cloud environment</br>
Create a *VPC* with the following characteristics:

```text
Name: Temenos VPC
IPv4: 10.0.0.0/16
```

After creating the *VPC*, select it and click:</br>
`Actions` -> `Edit DNS hostnames`</br>
Check the `DNS hostnames` option and click `Save`.

### Create the Subnets

For this runbook, you'll create **four** *Subnets*, two in each *AZ*.</br>
One *Subnet* from each *AZ* will be attached later on the *Internet Gateway* to be accessible over the internet.</br>
The other *Subnet* in each *AZ* will **not be** attached to *Internet Gateway* and therefore will not be accessible
over the internet.</br>

Create **four** *Subnets*, with the following characteristics:

```text
VPC: <select Temenos VPC>
Subnet Name: Temenos Public us-east-1a Subnet
Availability Zone: us-east-1a
IPv4 CIDR block: 10.0.1.0/24
```

```text
VPC: <select Temenos VPC>
Subnet Name: Temenos Private us-east-1a Subnet
Availability Zone: us-east-1a
IPv4 CIDR block: 10.0.2.0/24
```

```text
VPC: <select Temenos VPC>
Subnet Name: Temenos Public us-east-1b Subnet
Availability Zone: us-east-1b
IPv4 CIDR block: 10.0.3.0/24
```

```text
VPC: <select Temenos VPC>
Subnet Name: Temenos Private us-east-1b Subnet
Availability Zone: us-east-1b
IPv4 CIDR block: 10.0.4.0/24
```

After creating the *Subnets*, select **each of the two Public ones** and click:</br>
`Actions` -> `Modify auto-assign IP settings`</br>
Check the `Enable auto-assign public IPv4 address` option and click `Save`.

### Create the NAT Gateway

The *NAT Gateway* will allow the instances to access the internet.</br>
Create a *NAT Gateway* with the following characteristics:

```text
Name: Temenos NAT Gateway
Subnet: <select Temenos Public us-east-1a Subnet>
Elastic IP allocation ID: <select Temenos NAT-GW us-east-1a EIP>
```

### Create the Internet Gateway

The *Internet Gateway* will allow the instance to be accessible over the internet.</br>
Subnets attached to this gateway, are implicitly public.</br>
Create an *Internet Gateway* with the following characteristics:

```text
Name: Temenos Internet Gateway
```

Select the new gateway and click:</br>
*Actions* -> *Attach*</br>
Attach the gateway to the Temenos VPC.

### Create the Route Tables

For this runbook, you need to create **two** *Route Tables*.</br>
The first one will be attached to the *NAT Gateway*,</br>
it will act as our **main** *Route Table* and will be adhered to by all of the *Subnets*.

The second one will be attached to the *Internet Gateway*,</br>
it will be explicitly set to the *Subnets* you designated as public ones.

Create a *Route Table* with the following characteristics:

```text
Name: Temenos NAT Route Table
VPC: <select Temenos VPC>
```

Click *Edit Routes* -> *Add Route*,</br>
and add a route with the following characteristics:

```text
Destination: 0.0.0.0/0
Target: <select Temenos NAT Gateway>
```

Click *Actions* -> *Set main route table*,</br>
to make the *NAT* table as the **main** table.</br>
While you're at it, feel free to delete the table that was marked as main for your *VPC* prior, it was created by
default, it has no more usage.

Create another *Route Table* with the following characteristics:

```text
Name: Temenos Internet Route Table
VPC: <select Temenos VPC>
```

Click *Edit Routes* -> *Add Route*,</br>
and add a route with the following characteristics:

```text
Destination: 0.0.0.0/0
Target: <select Temenos Internet Gateway>
```

Inside the route table, go to the *Subnet Association* tab,</br>
and associate this table to **both public designated Subnets**, *Temenos Public us-east-1a Subnet*
and *Temenos Public us-east-1b Subnet*.

### Create the Security Groups

The security groups encapsulate the network rules.</br>
Create **three** Security Groups with the following characteristics.

The first group is designated to be used by the JBoss frontend, meaning the *RHSSO*, *Business Central*, and
*KIE Server* instances:

```text
Name: temenos-jboss-front
Description: Temenos JBoss Front Security Group
VPC: <select Temenos VPC>
```

Add the following Inbound Rules to the frontend group:

```text
Type: Custom TCP -> Port range: 8080 -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Front Http
Type: Custom TCP -> Port range: 8443 -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Front Https
Type: Custom TCP -> Port range: 9990 -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Administration GUI
Type: SSH -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Connection SSH

```

Add the following Tag to the frontend group:

```text
Name=Temenos JBoss Front Security Group
```

The second group is designated to be used by the *PostgreSQL* backend instance:

```text
Name: temenos-postgresql-back
Description: Temenos PostgreSQL Back Security Group
VPC: <select Temenos VPC>
```

And add the following Inbound Rules to the backend group:

```text
Type: PostgreSQL -> Source: <select temenos-jboss-front> -> Description: Connection MySQL
```

Add the following Tag to the backend group:

```text
Name=Temenos PostgreSQL Back Security Group
```

The third group is designated to be used by the *Smart Router*:

```text
Name: temenos-smart-router
Description: Temenos Smart Router Security Group
VPC: <select Temenos VPC>
```

Add the following Inbound Rules to the frontend group:

```text
Type: Custom TCP -> Port range: 9999 -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: API Access
Type: SSH -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Connection SSH

```

Add the following Tag to the frontend group:

```text
Name=Temenos Smart Router Security Group
```

### Create the Subnet Group

Create a *Subnet Group* with the following characteristics:

```text
Name: temenos-postgresql-subnet-group
Description: Temenos PostgreSQL Subnet Group
VPC: <select Temenos VPC>
Availability Zones: <select us-east-1a and us-east-1b>
Subnets: <select the private subnets Temenos Private us-east-1a Subnet and Temenos Private us-east-1b Subnet>
Tags: Name=Temenos PostgreSQL Subnet Group
```

## Create the instances

### Create the PostgreSQL DB Managed RDS Instance

> Make sure you've selected a *db instance class* [here][19] before proceeding.

Create a *Database Instance* with the following characteristics:

Engine Options:

```text
Creation method: Standard create
Engine Type: PostgreSQL
Version: 11.13
```

Settings:

```text
Instance Identifier: temenos-postgresql-db
Master username: rhadmin
Master password: redhat123#
```

DB instance class: `<your chosen instance class>`

Connectivity:

```text
Virtual private cloud: <select Temenos VPC>
Subnet group: <select Temenos PostgreSQL Subnet Group>
VPC security group: <select Temenos PostgreSQL Back Security Group>
```

Additional configuration:

```text
Initial database name: jbpm
Log exports: PostgreSQL log
Enable auto minor version upgrade: unchecked
```

**Set the database centralized parameters**:

From your *PostgreSQL* instance, grab the *Endpoint* URI, it should look something like this:
`temenos-postgresql-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com`.

Jump over to the `System Manager` console and click [Parameter Store][36], create the following **four** parameters:

```text
Name: /temenos/rhpam/prod/database/host
Description: Temenos Production Database Host
Value: <type in the postgresql instance endpoint>
```

```text
Name: /temenos/rhpam/prod/database/password
Description: Temenos Production Database Password
Value: redhat123#
```

```text
Name: /temenos/rhpam/prod/database/port
Description: Temenos Production Database Port
Value: 5432
```

```text
Name: /temenos/rhpam/prod/database/username
Description: Temenos Production Database Username
Value: rhadmin
```

### Create the base EC2 Instance and AMI

Eventually, you'll need to create **four** *EC2* instances, for the following components:

- *RHSSO*, which will be used as an *AMI* for auto-scaling and accessed via an *Elastic Load Balancer*.
- *Business Central*, which will be used as a sole instance with an *Elastic IP* and accessed directly.
- *Smart Router*, which will be used as a sole instance with an *Elastic IP* and accessed directly.
- *KIE Server*, which will be used as an *AMI* for auto-scaling and will be accessed via the *Smart Router* and the
  *Business Central*.

But as these four instances have a lot in common in regards to installed packages and tools, you'll create five instances. The first one will be the source of a base *AMI* from which you'll create the other four.

Let's start, click `Launch Instance`:

**Choose AMI**:

Select *Red Hat Enterprise Linux 8* from the *EC2 AMI* list.</br>
For searching reference, the *AMI* id for a 64x86 version of *RHEL8* is `ami-0b0af3577fe5e3532`.

**Choose Instance Type**:

Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
Although it's not that important for this specific instance, as it's just for creating the base image.

**Configure Instance**:

Configure the *EC2 Instance* with the following characteristics:

> Note that for this specific base image, it doesn't matter what *Subnet*, *Security Group*  you select, as
> long as it's a public IP with TCP22 port opened for *SSH* connection.

```text
Network: <select Temenos VPC>
Subnet: <select Temenos Public us-east-1b Subnet>
Auto-assign Public IP: Enable
```

Add Tags:

```text
Tags: Name=Temenos Base Image
```

Configure Security Groups:

```text
Security Groups: <select temenos-jboss-front>
```

Review, click `Launch`, and select your `Key-Pair`.

Once the *EC2 Instance* is up and available, grab its public IP or DNS name from the console and use it to connect via
*SSH* using your *private Key-Pair*:

```shell
ssh -i /path/to/private.pem ec2-user@instance_public_ip_or_dns
```

Once you're in, run the following commands:

```shell
# upgrade install and configure repositories
sudo dnf upgrade -y
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf -qy module disable postgresql
# install various required packages
sudo dnf -y install postgresql11-server unzip bind-utils java-11-openjdk-devel
# install awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -r ./aws
rm awscliv2.zip
# install the service runner script
sudo mkdir /opt/service-runner
sudo curl -L \
    https://github.com/RHEcosystemAppEng/temenos-infinity-cib/blob/main/eap/rhpam-on-aws-with-managed-postgresql/run-service.sh?raw=true \
    -o /opt/service-runner/run-service.sh
sudo chmod a+x /opt/service-runner/run-service.sh
```

**Create the AMI**:

Get back to the *EC2* console, select the instance you've been working on and click:</br>
`Actions` -> `Image and templates` -> `Create image`</br>:
And create an image with the following characteristics:

```text
Image name: temenos-base-ami
Image description: Base image including PostgreSQL client, unzip, bind-utils, JDK 11, AWS CLI, and the service runner script.
Tags: Name=Temenos Base AMI
```

The *AMI* might take a couple of minutes to become available, while it's being built if you haven't closed your *SSH* connection, it will be terminated.

Once it's done, you can terminate the instance you've been working on, by selecting it console and clicking:</br>
`Instance state` -> `Terminate instance`</br>
If you want to keep it around a little bit longer, you can stop it instead of terminating it.</br>
Note the termination of an instance is a **final action**, the terminated instance will be deleted within one hour.

### Create the RHSSO Instance, AMI, ELB, and ASG

Click `Launch Instance`:

**Choose AMI**:

Select the base image `temenos-base-ami` you created.</br>

**Choose Instance Type**:

Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
Although it's not that important for this specific instance, as it's just for creating the rhsso image.

**Configure Instance**:

Configure the *EC2 Instance* with the following characteristics:

> Note that for this specific rhsso image, it doesn't matter what *Subnet*, you select, as long as it's a
> public IP, the auto-scaling configuration will eventually deploy to both public subnets.

```text
Network: <select Temenos VPC>
Subnet: <select Temenos Public us-east-1b Subnet>
Auto-assign Public IP: Enable
IAM role: <select temenos-ec2-get-parameters-role>
```

Add Tags:

```text
Tags: Name=Temenos RHSSO Image
```

Configure Security Groups:

```text
Security Groups: <select temenos-jboss-front>
```

Review, click `Launch`, and select your `Key-Pair`.

Once the *EC2 Instance* is up and available, grab its public IP or DNS name from the console and use it to copy the
files needed for the installation via *SSH* using your *private Key-Pair*:

```shell
scp -i /path/to/private.pem \
    /path/to/postgresql-42.3.0.jar \
    /path/to/rh-sso-7.4.0.zip \
    /path/to/rh-sso-7.4.9-patch.zip \
    ec2-user@instance_public_ip_or_dns:
```

Once done, connect to the instance using *SSH*:

```shell
ssh -i /path/to/private.pem ec2-user@instance_public_ip_or_dns
```

Once you're in, run the following commands:

```shell
# connect to postgresql and create the keycloak database (note the endpoint)
psql -h temenos-postgresql-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com -p 5432 -d jbpm -U rhadmin -W
# (password: redhat123#)
CREATE DATABASE keycloak;
exit
# install rhsso and apply patch
sudo unzip rh-sso-7.4.0.zip /opt
# start jboss cli in disconnected mode
sudo /opt/rh-sso-7.4/bin/jboss-cli.sh
# install the patch
patch apply /home/ec2-user/rh-sso-7.4.9-patch.zip
# add the postgresql module
module add --name=org.postgresql --resources=~/postgresql-42.3.0.jar --dependencies=javax.api,javax.transaction.api
# exit jboss cli
exit
```

You now need to use the *jboss-cli* in connected mode, meaning you need to start the server:

```shell
sudo /opt/rh-sso-7.4/bin/standalone.sh -c standalone.xml
```

Connect via *SSH* from a **different terminal session** and run the following commands:

```shell
# start jboss cli in connected mode
sudo /opt/rh-sso-7.4/bin/jboss-cli.sh --connect
# configure the postgresql jdbc driver
/subsystem=datasources/jdbc-driver=postgres:add(driver-name="postgres",driver-module-name="org.postgresql",driver-class-name=org.postgresql.Driver)
# test the current h2 db setup
/subsystem=datasources/data-source=KeycloakDS:test-connection-in-pool
# remove the default h2 db configuration
data-source remove --name=KeycloakDS
# add the postgresql datasource (note the endpoint)
data-source add --jndi-name=java:/KeycloakDS \
    --name=KeycloakDS \
    --connection-url=jdbc:postgresql://temenos-postgresql-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com:5432/keycloak \
    --driver-name=postgres \
    --user-name=rhadmin \
    --password=redhat123#
# reoload the configuration
:reload
# test the postgresql db setup
/subsystem=datasources/data-source=KeycloakDS:test-connection-in-pool
# exit jboss cli
exit
# add the admin user to the keycloack
sudo /opt/rh-sso-7.4/bin/add-user-keycloak.sh --user admin
# (password: redhat123#)
```

Close the terminal session you've been working with, and switch back to the session running the server.</br>
Press `Control+C`/`Command+.` to stop the server, and edit the `/opt/rh-sso-7.4/standalone/configuration/standalone.xml`:

***************************************
UNDER CONSTRUCTION - ADD XML DIFFS HERE
***************************************

Cleanup:

```shell
rm ~/postgresql-42.3.0.jar ~/rh-sso-7.4.0.zip ~/rh-sso-7.4.9-patch.zip
```

Create the system service for running the *RHSSO* server:

```shell
sudo bash -c 'cat << EOF > /etc/systemd/system/rhsso.service
[Unit]
Description=RHSSO Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/opt/service-runner/run-service.sh rh-sso
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
```

And run the following commands to start and enable the service:

```shell
sudo systemctl start rhsso.service
sudo systemctl enable rhsso.service
# you can use the following journalctl command to view the server log
sudo journalctl -u rhsso.service -f
```

Once done, access the server using your browser: [https://instance_public_ip_or_dns:8443/auth].</br>
Use the instance's IP or DNS name, of course, note that *HTTPS* is mandatory, so accept the presented certificates.</br>
Use the *admin/redhat123#* user to log in and:

**Create the Realm**:

Hover mouse on the current *master* realm, click `Add Realm` and name it *Temenos*.</br>
Select the new *Temenos* realm.

**Create the Roles**:

In the `Configure` -> `Roles` page, click `Add Role`, and **three** roles with the following names:

- *admin*
- *kie-server*
- *rest-all*

**Create the User**:

In the `Manage` -> `Users` page, click `Add User`, create a user with `Username` *rhpam*.</br>
After saving:

- Step into the `Credentials` tab, toggle off `Temporary`, and set the password to *redhat*.
- Step into the `Role Mappings` tab and assign the **three** roles created, *admin*, *kie-server*, and *rest-all*.
- In the `Client Roles`, type *realm-management* and select it, add the *realm-admin* role.

**Create the clients**:

In the `Configure` -> `Clients` page, click `Create` and create **three** clients with the following characteristics,
for each client you create, grab the `Secret` value from the `Credentials` tab, you'll need it later on:

> For the *business-central* client, use the *EIP* you designated for the *Business Central* as the redirection Host.

```text
Client ID: business-central
Client Protocol: openid-connect
Access Type: confidential
Valid Redirect URIs: http://<Temenos Business Central us-east-1b EIP>:8080/business-central/*
```

> For the *kie-server* and *smart-router* clients, you can keep the localhost redirection host, the clients are used for
> client tokens retrieval only and not for authenticating users.

```text
Client ID: kie-server
Client Protocol: openid-connect
Access Type: confidential
Valid Redirect URIs: http://localhost:8080/kie-server/*
```

```text
Client ID: smart-router
Client Protocol: openid-connect
Access Type: confidential
Valid Redirect URIs: http://localhost:8080/smart-router/*
```

**Create the AMI**:

Get back to the *EC2* console, select the instance you've been working on and click:</br>
`Actions` -> `Image and templates` -> `Create image`</br>:
And create an image with the following characteristics:

```text
Image name: temenos-rhsso-ami
Image description: RHSSO AMI configured for working with RHPAM
Tags: Name=Temenos RHSSO AMI
```

The *AMI* might take a couple of minutes to become available, while it's being built if you haven't closed your *SSH*
connection, it will be terminated.

Once it's done, you can terminate the instance you've been working on, by selecting it console and clicking:</br>
`Instance state` -> `Terminate instance`</br>
If you want to keep it around a little bit longer, you can stop it instead of terminating it.</br>
Note the termination of an instance is a **final action**, the terminated instance will be deleted within one hour.

**Create the Target Groups**:

From the *EC2* console, go into `Load Balancing` -> `Target Groups`, create **two** *Target Groups*, with the following
characteristics:

> Note that you're using the `TCP` protocol and not the more suitable `HTTPS`/`HTTPS` ones as a workaround, using
> `HTTPS` requires a certificate to be configured within the *ASG* later on.

```text
Target type: Instances
Target group name: temenos-rhsso-tcp-8443-tg
Protocol: TCP
Port: 8443
VPC: <select Temenos VPC>
Tags: Name=Temenos RHSSO TCP8443 Target Group
```

```text
Target type: Instances
Target group name: temenos-rhsso-tcp-8080-tg
Protocol: TCP
Port: 8080
VPC: <select Temenos VPC>
Tags: Name=Temenos RHSSO TCP8080 Target Group
```

**Create the Load Balancer**:

From the *EC2* console, go into `Load Balancing` -> `Load Balancers`, create a load balancer with the following
characteristics, after you create the load balancer, note the *DNS Name*, you'll use it later on:

```text
Load balancer type: Network Load Balancer
Load balancer name: temenos-rhsso-nlb
VPC: <select Temenos VPC>
Mappings: <select both AZ us-east-1a and us-east-1b and use the Public subnets for each>
Tags: Name=Temenos RHSSO Network Load Balancer
```

Before saving, add **two** *Listeners* with the following characteristics:

```text
Protocol: TCP
Port: 8443
Default action: Forward to - temenos-rhsso-tcp-8443-tg
```

```text
Protocol: TCP
Port: 8080
Default action: Forward to - temenos-rhsso-tcp-8080-tg
```

**Create the Launch Configuration**:

From the *EC2* console go into `Auto Scaling` -> `Launch Configuration` and create a *Launch Configuration* with the
following characteristics:

> Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
> The minimum requirements are **2CPUs and 2GiB memory**, for creating this runbook, we used `t2.medium`.

```text
Name: temenos-rhsso-launch-config
AMI: <select temenos-rhsso-ami>
Instance type: <your selected instance type>
Security Groups: <select temenos-jboss-front>
Key pair: <select your key-pair>
```

**Create the Auto Scaling Group**:

From the *EC2* console go into `Auto Scaling` -> `Auto Scaling Groups` and create an *Auto Scaling Group* with the
following characteristics (make sure to click `Switch to launch configuration`):

```text
Name: temenos-rhsso-asg
Launch configuration: <select temenos-rhsso-launch-config>
VPC: <select Temenos VPC>
Availability Zones and subnets: <select both Temenos RHPAM Public Subnet east-1a and Temenos RHPAM Public Subnet east-1b>
Load balancing: <Attach to an existing load balancer - temenos-rhsso-nlb>
Group size: <set the group size as you want, i.e. desired=2, minimum=2,maximum=6>
Tags: Name=Temenos RHSSO
```

**Set the RHSSO centralized parameters**:

Jump over to the `System Manager` console and click [Parameter Store][36], create the following **eight** parameters:

```text
Name: /temenos/rhpam/prod/rh-sso/host
Description: Temenos Production RHSSO Host
Value: <type in the rhsso load balancer dns name>
```

```text
Name: /temenos/rhpam/prod/rh-sso/password
Description: Temenos Production RHSSO Password
Value: redhat
```

```text
Name: /temenos/rhpam/prod/rh-sso/port
Description: Temenos Production RHSSO Port
Value: 8080
```

```text
Name: /temenos/rhpam/prod/rh-sso/realm
Description: Temenos Production RHSSO Realm
Value: Temenos
```

```text
Name: /temenos/rhpam/prod/rh-sso/secrets/business-central
Description: Temenos Production RHSSO Business Central Secret
Value: <type in the secret for the business-central client>
```

```text
Name: /temenos/rhpam/prod/rh-sso/secrets/kie-server
Description: Temenos Production RHSSO KIE Server Secret
Value: <type in the secret for the kie-server client>
```

```text
Name: /temenos/rhpam/prod/rh-sso/secrets/smart-router
Description: Temenos Production RHSSO Smart Router Secret
Value: <type in the secret for the smart-router client>
```

```text
Name: /temenos/rhpam/prod/rh-sso/username
Description: Temenos Production RHSSO Username
Value: rhpam
```

### Create the Business Central instance

Click `Launch Instance`:

**Choose AMI**:

Select the base image `temenos-base-ami` you created.</br>

**Choose Instance Type**:

Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
The minimum requirements are **2CPUs and 2GiB memory**, for creating this runbook, we used `t2.medium`.

**Configure Instance**:

Configure the *EC2 Instance* with the following characteristics:

```text
Network: <select Temenos VPC>
Subnet: <select Temenos Public us-east-1b Subnet>
Auto-assign Public IP: Enable
IAM role: <select temenos-ec2-get-parameters-role>
```

Add Tags:

```text
Tags: Name=Temenos RHPAM Business Central
```

Configure Security Groups:

```text
Security Groups: <select temenos-jboss-front>
```

Review, click `Launch`, and select your `Key-Pair`.

From the *EC2* console, got into the `Network & Security` -> `Elastic IPs`, select the *EIP* you desiganted for the
*Business Central*, click `Actions` -> `Associate Elastic IP address` and select the *Business Central* instance you
created.

Once the *EC2 Instance* is up and available, use its *EIP* to copy the files needed for the installation via *SSH* using
your *private Key-Pair*:

```shell
scp -i /path/to/private.pem \
    /path/to/jboss-eap-7.3.0-installer.jar \
    /path/to/jboss-eap-7.3.6-patch.zip \
    /path/to/rhpam-installer-7.11.1.jar \
    /path/to/rh-sso-7.4.0-eap7-adapter.zip \
    ec2-user@business_central_elastic_ip:
```

Once done, connect to the instance using *SSH*:

```shell
ssh -i /path/to/private.pem ec2-user@business_central_elastic_ip
```

Once you're in, run the following commands:

```shell
# create a folder for jboss eap
sudo mkdir /opt/EAP-7.3.0
# run jboss installer, use `/opt/EAP-7.3.0` for the path, use `admin` and `redhat123#` for the user and password
sudo java -jar jboss-eap-7.3.0-installer.jar
# start jboss cli in disconnected mode
sudo /opt/EAP-7.3.0/bin/jboss-cli.sh
# apply the patch
patch apply /home/ec2-user/jboss-eap-7.3.6-patch.zip
# exit jboss cli
exit
# load the sso adapter into jboss
sudo unzip rh-sso-7.4.0-eap7-adapter.zip -d /opt/EAP-7.3.0/
# configure standalone-full with the rhsso adapter
sudo /opt/EAP-7.3.0/bin/jboss-cli.sh \
    --file=/opt/EAP-7.3.0/bin/adapter-elytron-install-offline.cli \
    -Dserver.config=standalone-full.xml
# run rhpam installer, use `/opt/EAP-7.3.0` for the path, use `admin` and `redhat123#` for the user and password
# when selecting components to be installed, ONLY SELECT THE BUSINESS CENTRAL
sudo java -jar rhpam-installer-7.11.1.jar
# remove redundant deployment
sudo rm /opt/EAP-7.3.0/standalone/deployments/business-central.war/WEB-INF/lib/uberfire-security-management-wildfly-7.52.0.Final-redhat-00008.jar
```

**Optionally set a custom Maven repository**:

By default, *RHPAM* uses [Red Hat's public maven repository][37], if you intend to use your own, i.e. if you plan to run
the [Validation Procedure](ValidationProcedure.md) at the end of this runbook, you'll need to create a maven settings
file with authorization info for the repository.

For the sake of following the [Validation Procedure](ValidationProcedure.md), use the maven repository created by
Daniele in [repsy.io](repsy.io) for this runbook.

Create the designated folder for storing the configuration, and add the settings file:

```shell
sudo mkdir /opt/custom-config
sudo bash -c 'cat << EOF > /opt/custom-config/settings.xml
<settings>
    <servers>
        <server>
            <id>rhpam</id>
            <username>dmartino</username>
            <password>dMartino123</password>
        </server>
    </servers>
</settings>
EOF'
```

> Note that this configuration means that whenever the Business Central need to deploy an artifact to a
> *Distribution Repository* named *rhpam* it will use the above username and password. The deployed artifact's pom
> should declare the *rhpam* repository as in the distribution management section.

***************************************
UNDER CONSTRUCTION - ADD XML DIFFS HERE
***************************************

Cleanup:

```shell
rm ~/jboss-eap-7.3.0-installer.jar ~/jboss-eap-7.3.6-patch.zip ~/rhpam-installer-7.11.1.jar ~/rh-sso-7.4.0-eap7-adapter.zip
```

Create the system service for running the *Business Central* server:

```shell
sudo bash -c 'cat << EOF > /etc/systemd/system/business-central.service
[Unit]
Description=Business Central Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/opt/service-runner/run-service.sh business-central
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
```

And run the following commands to start and enable the service:

```shell
sudo systemctl start business-central.service
sudo systemctl enable business-central.service
# you can use the following journalctl command to view the server log
sudo journalctl -u business-central.service -f
```

Once done, you should be able to access the server using your browser:
[http://business_central_elastic_ip:8080/business-central].</br>
Use the *Business Central EIP*, you will be directed to the *RHSSO* server for authentication, use `rhpam` and `redhat`
as user and password, this will redirect you back to the *Business Central* session.

**Set the Business Central centralized parameters**:

Jump over to the `System Manager` console and click [Parameter Store][36], create the following **two** parameters:

```text
Name: /temenos/rhpam/prod/business-central/host
Description: Temenos Production Business Central Host
Value: <type in public elastic ip or dns name of the business central instance>
```

```text
Name: /temenos/rhpam/prod/business-central/port
Description: Temenos Production Business Central Port
Value: 8080
```

### Create the Smart Router instance

Click `Launch Instance`:

**Choose AMI**:

Select the base image `temenos-base-ami` you created.</br>

**Choose Instance Type**:

Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
For creating this runbook, we used `t2.medium`.

**Configure Instance**:

Configure the *EC2 Instance* with the following characteristics:

```text
Network: <select Temenos VPC>
Subnet: <select Temenos Public us-east-1b Subnet>
Auto-assign Public IP: Enable
IAM role: <select temenos-ec2-get-parameters-role>
```

Add Tags:

```text
Tags: Name=Temenos RHPAM Smart Router
```

Configure Security Groups:

```text
Security Groups: <select temenos-smart-router>
```

Review, click `Launch`, and select your `Key-Pair`.

From the *EC2* console, get into the `Network & Security` -> `Elastic IPs`, select the *EIP* you designated for the
*Smart Router*, click `Actions` -> `Associate Elastic IP address` and select the *Smart Router* instance you created.

Once the *EC2 Instance* is up and available, use its *EIP* to copy the file needed for the installation via *SSH* using
your *private Key-Pair*:

```shell
scp -i /path/to/private.pem \
    /path/to/rhpam-7.11.1-smart-router.jar \
    ec2-user@smart_router_elastic_ip:
```

Once done, connect to the instance using *SSH*:

```shell
ssh -i /path/to/private.pem ec2-user@smart_router_elastic_ip
```

Once you're in, run the following commands:

```shell
# create the folders for the smart router server
sudo mkdir -p /opt/smartrouter/repo
# move the jar file into its new home
sudo mv rhpam-7.11.1-smart-router.jar /opt/smartrouter/
```

Create the system service for running the *Smart Router* server:

```shell
sudo bash -c 'cat << EOF > /etc/systemd/system/smart-router.service
[Unit]
Description=Smart Router Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/opt/service-runner/run-service.sh smart-router
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
```

And run the following commands to start and enable the service:

```shell
sudo systemctl start smart-router.service
sudo systemctl enable smart-router.service
# you can use the following journalctl command to view the server log
sudo journalctl -u smart-router.service -f
```

Once done, you should be able to view the router state using your browser: [http://smart_router_elastic_ip:9999/mgmt/list].

**Set the Smart Router centralized parameters**:

Jump over to the `System Manager` console and click [Parameter Store][36], create the following **two** parameters:

```text
Name: /temenos/rhpam/prod/smart-router/host
Description: Temenos Production Smart Router Host
Value: <type in public elastic IP or DNS name of the smart router instance>
```

```text
Name: /temenos/rhpam/prod/smart-router/port
Description: Temenos Production Smart Router Port
Value: 9999
```

### Create the KIE Server Instance, AMI, and ASG

Click `Launch Instance`:

**Choose AMI**:

Select the base image `temenos-base-ami` you created.</br>

**Choose Instance Type**:

Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
Although it's not that important for this specific instance, as it's just for creating the kie server image.

**Configure Instance**:

Configure the *EC2 Instance* with the following characteristics:

> Note that for this specific kie server image, it doesn't matter what *Subnet*, you select, as long as it's a
> public IP, the auto-scaling configuration will eventually deploy to both public subnets.

```text
Network: <select Temenos VPC>
Subnet: <select Temenos Public us-east-1b Subnet>
Auto-assign Public IP: Enable
IAM role: <select temenos-ec2-get-parameters-role>
```

Add Tags:

```text
Tags: Name=Temenos KIE Server Image
```

Configure Security Groups:

```text
Security Groups: <select temenos-jboss-front>
```

Review, click `Launch`, and select your `Key-Pair`.

Once the *EC2 Instance* is up and available, grab its public IP or DNS name from the console and use it to copy the
files needed for the installation via *SSH* using your *private Key-Pair*:

```shell
scp -i /path/to/private.pem \
    /path/to/postgresql-42.3.0.jar \
    /path/to/jboss-eap-7.3.0-installer.jar \
    /path/to/jboss-eap-7.3.6-patch.zip \
    /path/to/rhpam-installer-7.11.1.jar \
    /path/to/rhpam-7.11.1-migration-tool.zip \
    /path/to/rh-sso-7.4.0-eap7-adapter.zip \
    ec2-user@instance_public_ip_or_dns:
```

Once done, connect to the instance using *SSH*:

```shell
ssh -i /path/to/private.pem ec2-user@instance_public_ip_or_dns
```

Once you're in, run the following commands:

```shell
# create a folder for jboss eap
sudo mkdir /opt/EAP-7.3.0
# run jboss installer, use `/opt/EAP-7.3.0` for the path, use `admin` and `redhat123#` for the user and password
sudo java -jar jboss-eap-7.3.0-installer.jar
# create path for the postgresql connector
sudo mkdir -p /opt/EAP-7.3.0/modules/system/layers/base/org/postgresql/main
cd /opt/EAP-7.3.0/modules/system/layers/base/org/postgresql/main
# move the connector jar file to the created path
sudo mv ~/postgresql-42.3.0.jar .
# create a module descriptor for the connector
sudo bash -c 'cat << EOF > module.xml
<module xmlns="urn:jboss:module:1.5" name="org.postgresql">
    <resources>
        <resource-root path="postgresql-42.3.0.jar"/>
    </resources>
    <dependencies>
        <module name="javax.api"/>
        <module name="javax.transaction.api"/>
    </dependencies>
</module>
EOF'
# go back home and unzip the migration tools archive
cd ~
unzip rhpam-7.11.1-migration-tool.zip
cd rhpam-7.11.1-migration-tool/ddl-scripts/postgresql
# run the following three sql scripts for creating the database structure (note the endpoint)
# password is redhat123#
psql -h temenos-postgresql-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com -p 5432 -U rhadmin -d jbpm -W < postgresql-jbpm-schema.sql
psql -h temenos-postgresql-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com -p 5432 -U rhadmin -d jbpm -W < quartz_tables_postgres.sql
psql -h temenos-postgresql-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com -p 5432 -U rhadmin -d jbpm -W < task_assigning_tables_postgresql.sql
# start jboss cli in disconnected mode
sudo /opt/EAP-7.3.0/bin/jboss-cli.sh
# apply the patch
patch apply /home/ec2-user/jboss-eap-7.3.6-patch.zip
# add the postgresql connector
module add --name=org.postgresql \
    --resources=/opt/EAP-7.3.0/modules/system/layers/base/org/postgresql/main/postgresql-42.3.0.jar \
    --dependencies=javax.api,javax.transaction.api
# exit jboss cli
exit
# load the sso adapter into jboss
sudo unzip rh-sso-7.4.0-eap7-adapter.zip -d /opt/EAP-7.3.0/
# configure standalone-full with the rhsso adapter
sudo /opt/EAP-7.3.0/bin/jboss-cli.sh \
    --file=/opt/EAP-7.3.0/bin/adapter-elytron-install-offline.cli \
    -Dserver.config=standalone-full.xml
# run rhpam installer, use `/opt/EAP-7.3.0` for the path, use `admin` and `redhat123#` for the user and password
# when selecting components to be installed, ONLY SELECT THE KIE SERVER
sudo java -jar rhpam-installer-7.11.1.jar
```

**Optionally set a custom Maven repository**:

By default, *RHPAM* uses [Red Hat's public maven repository][37], if you intend to use your own, i.e. if you plan to run
the [Validation Procedure](ValidationProcedure.md) at the end of this runbook, you'll need to create a maven settings
file with authorization info for the repository.

For the sake of following the [Validation Procedure](ValidationProcedure.md), use the maven repository created by
Daniele in [repsy.io](repsy.io) for this runbook.

Create the designated folder for storing the configuration, and add the settings file:

```shell
sudo mkdir /opt/custom-config
sudo bash -c 'cat << EOF > /opt/custom-config/settings.xml
<settings>
    <servers>
        <server>
            <id>rhpam</id>
            <username>dmartino</username>
            <password>dMartino123</password>
        </server>
    </servers>
    <profiles>
        <profile>
            <id>custom-repo</id>
            <activation>
                <activeByDefault>true</activeByDefault>
            </activation>
            <repositories>
                <repository>
                    <id>rhpam</id>
                    <url>https://repo.repsy.io/mvn/dmartino/rhpam</url>
                </repository>
            </repositories>
        </profile>
    </profiles>
</settings>
EOF'
```

> Note that you can omit the *servers* section if the *rhpam* repository is a public one.

***************************************
UNDER CONSTRUCTION - ADD XML DIFFS HERE
***************************************

Cleanup:

```shell
rm ~/postgresql-42.3.0.jar \
    ~/jboss-eap-7.3.0-installer.jar \
    ~/jboss-eap-7.3.6-patch.zip \
    ~/rhpam-installer-7.11.1.jar \
    ~/rhpam-7.11.1-migration-tool.zip \
    ~/rh-sso-7.4.0-eap7-adapter.zip
rm -r ~/rhpam-7.11.1-migration-tool
```

Create the system service for running the *RHSSO* server:

```shell
sudo bash -c 'cat << EOF > /etc/systemd/system/kie-server.service
[Unit]
Description=KIE Server Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/opt/service-runner/run-service.sh kie-server
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
```

And run the following commands to start and enable the service:

```shell
sudo systemctl start kie-server.service
sudo systemctl enable kie-server.service
# you can use the following journalctl command to view the server log
sudo journalctl -u kie-server.service -f
```

**Create the AMI**:

Get back to the *EC2* console, select the instance you've been working on and click:</br>
`Actions` -> `Image and templates` -> `Create image`</br>:
And create an image with the following characteristics:

```text
Image name: temenos-kie-server-ami
Image description: RHPAM KIE Server AMI
Tags: Name=Temenos KIE Server AMI
```

The *AMI* might take a couple of minutes to become available, while it's being built if you haven't closed your *SSH*
connection, it will be terminated.

Once it's done, you can terminate the instance you've been working on, by selecting it console and clicking:</br>
`Instance state` -> `Terminate instance`</br>
If you want to keep it around a little bit longer, you can stop it instead of terminating it.</br>
Note the termination of an instance is a **final action**, the terminated instance will be deleted within one hour.

**Create the Launch Configuration**:

From the *EC2* console go into `Auto Scaling` -> `Launch Configuration` and create a `Launch Configuration` with the
following characteristics:

> Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
> The minimum requirements are **2CPUs and 2GiB memory**, for creating this runbook, we used `t2.medium`.

```text
Name: temenos-kie-server-launch-config
AMI: <select temenos-kie-server-ami>
Instance type: <your selected instance type>
Security Groups: <select temenos-jboss-front>
Key pair: <select your key-pair>
```

**Create the Auto Scaling Group**:

From the *EC2* console go into `Auto Scaling` -> `Auto Scaling Groups` and create an *Auto Scaling Group* with the
following characteristics (make sure to click `Switch to launch configuration`):

```text
Name: temenos-kie-server-asg
Launch configuration: <select temenos-kie-server-launch-config>
VPC: <select Temenos VPdd />
Availability Zones and subnets: <select both Temenos RHPAM Public Subnet east-1a and Temenos RHPAM Public Subnet east-1b>
Group size: <set the group size as you want, i.e. desired=2, minimum=2,maximum=6>
Tags: Name=Temenos KIE Server
```

## Run a procedure validating the infrastructure

Run the [Validation Procedure](ValidationProcedure.md), Good luck!

<!-- Links -->
[0]: https://aws.amazon.com/
[1]: https://console.aws.amazon.com/
[8]: https://www.redhat.com/en/technologies/jboss-middleware/process-automation-manager
[9]: https://www.redhat.com/en/technologies/jboss-middleware/application-platform
[14]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
[18]: https://access.redhat.com/articles/3405381
[19]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
[21]: https://access.redhat.com/products/red-hat-single-sign-on
[22]: https://aws.amazon.com/about-aws/global-infrastructure/regions_az/
[23]: https://console.aws.amazon.com/ec2/v2/home#KeyPairs
[24]: https://app.asana.com/0/1200498898048415/1201006547552961/f
[25]: https://jdbc.postgresql.org/download.html
[26]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=core.service.rhsso&version=7.4
[27]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?product=core.service.rhsso&downloadType=patches&version=7.4
[28]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=appplatform&version=7.3
[29]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?product=appplatform&downloadType=patches&version=7.3
[30]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?product=rhpam&downloadType=distributions&version=7.11.1
[31]: https://console.aws.amazon.com/vpc/home
[32]: https://console.aws.amazon.com/rds/home
[33]: https://console.aws.amazon.com/ec2/v2/home
[34]: https://console.aws.amazon.com/systems-manager/home
[35]: https://console.aws.amazon.com/iamv2/home
[36]: https://console.aws.amazon.com/systems-manager/parameters
[37]: https://maven.repository.redhat.com/ga/
