# Deploy RHPAM 7.11.1 AWS with a PostgreSQL backend

## Document goal

Walkthrough the installation and deployment of [RHPAM][8] running on [JBoss EAP][9] with a `Smart Router` and  RHSSO[21] on [AWS][0].
Leveraging parameter centralizing, load balancig, auto-scaling, and network segmentation.</br>

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
balancing the requests for *RHSSO*, requires a minumum of **two** availibilty zones in the same region.</br>
For this procedure, you'll be using `us-east-1` as the region, and `us-east-1a` and `us-east-1b` as the availability zones.

## Instance Types and Classes

For the manages *PostgreSQL RDS Insatnce*, you can use one of the instance classes listed [here][19], `db.t2.micro` was
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
- [Red Hat Process Automation Manager 7.11.1 Business Central Deployable for EAP 7][30]
- [Red Hat Process Automation Manager 7.11.1 Add-Ons][30]

Extract the last downloded file `rhpam-7.11.1-add-ons` and grab the following files:

- `rhpam-7.11.1-migration-tool.zip`
- `rhpam-7.11.1-smart-router.zip`

### Prerequisite: Open URLs

Although you can reach everything from the console[0],
Here are the links for the services and components you'll work with:

- [AWS VPC][31] - *Virtual Private Cloud*, *Subnets*, *Route Tables*, *Internet Gateway*, and *NAT Gateway*.
- [AWS RDS][32] - *Database Instance* and *Subnet Groups*.
- [AWS EC2][33] - *EC2 Instances*, *Amazon Machine Images*, *Security Groups*, *Elastic IPs*, *Key Pairs*, *Load Balancer*,
  *Target Groups*, *Launch Configurations*, and *Auto Scaling Groups*.
- [AWS System Manager][34] - *Parameters Store*
- [AWS IAM][35] - *Roles* and *Policies*

### Prerequisite: Prepare a Key-Pair

You'll use *SSH* to connect to the various *EC2* instances, you can create a new *Key-Pair* or import your own [here][23].</br>
You can use the same key for multiple insances.

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
> There's no particular reason for that, mainly, you have only one of each, so a load splliting seems like a good idea.

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
One *Subnet* from each *AZ* will be attached later on the *Internet Gateway* in order to be accessible over the
internet.</br>
The the other *Subnet* in each *AZ* will **not be** attached to *Internet Gateway* and therefore will not be accessible
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

### Create the Route Table

For this runbook, you need to create **two** *Route Tables*.</br>
The first one will be attached to the *NAT Gateway*,</br>
it will act as our **main** *Route Table* and will be adhered to by all of the *Subnets*.

The second one will be attached to the *Internet Gateway*,</br>
it will be explicitly set to the *Subnets* you designated as a public ones.

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

The security groups enacapsulates the network rules.</br>
Create **three** Security Groups with the following characteristics.

The first group will designated to be used by the JBoss frontend, meaning the *RHSSO*, *Business Central*, and
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

The third group will designated to be used by the *Smart Router*:

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

#### Set the database centralized parameters

From you *PostrgeSQL* instance, grab the *Endpoint* URI, it should look something like this:
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

- *RHSSO*, which will be used as an *AMI* for auto scaling and accessed via an *Elastic Load Balancer*.
- *Business Central*, which will be used as a sole instance with an *Elastic IP* and accesed directly.
- *Smart Router*, which will be used as a sole instance with an *Elastic IP* and accessed directly.
- *KIE Server*, which will be used as an *AMI* for auto scaling and will be accessed via the *Smart Router* and the
  *Business Central*.

But as these four instances has a lot in common in regards to installed packages and tools, you'll actually create five
instances. The first one will be the source of a base *AMI* from which you'll create the other four.

Let's start, click `Launch Instance`:

**Choose AMI**:

Select *Red Hat Enterprise Linux 8* from the *EC2 AMI* list.</br>
For searching reference, the *AMI* id for a 64x86 version of *RHEL8* is `ami-0b0af3577fe5e3532`.

**Choose Instance Type**:

Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
The minimum requirements are **2CPUs and 2GiB memory**.
Although it is not critical for this specific instance, as it's just for creating the base image.

**Configure Instance**:

Configure the *EC2 Instance* with the following characteristics:

> Note that for this specific base image, it doesn't really matters what *Subnet*, *Security Group*  you select, as
> long as it's a public ip with TCP22 port opend for *SSH* connection.

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

Review, click `Launch` and select your `Key-Pair`.

Once the *EC2 Instance* is up and available, grab its public IP or DNS name from the console and use it to connect via
*SSH* using your *private Key-Pair*:

```shell
ssh -i /path/to/private.pem ec2-user@instance_public_ip_or_dns
```

Once you're in, run the following commands:

```shell
sudo dnf upgrade -y
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf -qy module disable postgresql
sudo dnf -y install postgresql11-server unzip bind-utils java-11-openjdk-devel
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -r ./aws
rm awscliv2.zip
sudo mkdir /opt/service-runner
sudo curl -L \
    https://github.com/RHEcosystemAppEng/temenos-infinity-cib/blob/main/eap/rhpam-on-aws-with-managed-postgresql/run-service.sh?raw=true \
    -o /opt/service-runner/run-service.sh
sudo chmod a+x /opt/service-runner/run-service.sh
```

Get back to the console, select the instance you've been working on and click:</br>
`Actions` -> `Image and templates` -> `Create image`</br>:
And create an image with the following characteristics:

```text
Image name: temenos-base-ami
Image description: Base image including postgresql client, unzip, bind-utils, jdk 11, aws cli, and the service runner script.
Tags: Name=Temenos Base AMI
```

The *AMI* might take a couple of minutes to become available, while it's being built, if you haven't closed your *SSH*
connection, it will be terminated.

Once it's done, you can terminate the instance you've been working on, by selecting it console and clicking:</br>
`Instance state` -> `Terminate instance`</br>
If you want to keep it around a little bit longer, you can stop it instead of termianting it.</br>
Note the termination of an instance is a **final action**, the termianted instance will be deletes within one hour.

### Create the RHSSO instance and AMI

click `Launch Instance`:

**Choose AMI**:

Select the base image `temenos-base-ami` you created.</br>

**Choose Instance Type**:

Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
The minimum requirements are **2CPUs and 2GiB memory**.

**Configure Instance**:

Configure the *EC2 Instance* with the following characteristics:

> Note that for this specific rhsso image, it doesn't really matters what *Subnet*, you select, as long as it's a
> public ip, the load balancer you will eventually create will deploy to both public subnets.

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

Review, click `Launch` and select your `Key-Pair`.

Once the *EC2 Instance* is up and available, grab its public IP or DNS name from the console and use it to copy the
files needed for the insallation via *SSH* using your *private Key-Pair*:

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

Once you're in, run the following commands (note the db endpoint for twice):

```shell
psql -h rhpam-postgresql-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com -p 5432 -d jbpm -U rhadmin -W
(password: redhat123#)
CREATE DATABASE keycloak;
exit
sudo unzip rh-sso-7.4.0.zip /opt
sudo /opt/rh-sso-7.4/bin/jboss-cli.sh
patch apply /home/ec2-user/rh-sso-7.4.9-patch.zip
module add --name=org.postgresql --resources=~/postgresql-42.3.0.jar \
    --dependencies=javax.api,javax.transaction.api \
    /subsystem=datasources/jdbc-driver=postgres:add(driver-name="postgres",driver-module-name="org.postgresql",driver-class-name=org.postgresql.Driver)
data-source remove --name=KeycloakDS
data-source add --jndi-name=java:/KeycloakDS \
    --name=KeycloakDS \
    --connection-url=jdbc:postgresql://rhpam-postgresql-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com:5432/keycloak \
    --driver-name=postgres \
    --user-name=rhadmin \
    --password=redhat123#
exit
```































#### Copy files

Use `scp` to copy the files you downloaded at the start of this document over ssh (note
*ec2_instance_public*):

```shell
scp /path/to/rhpam-7.9.0-add-ons.zip ec2-user@ec2_instance_public:/home/ec2-user
scp /path/to/jboss-eap-7.3.0-installer.jar ec2-user@ec2_instance_public:/home/ec2-user
scp /path/to/rhpam-installer-7.9.0.jar ec2-user@ec2_instance_public:/home/ec2-user
scp /path/to/mysql-connector-java-8.0.25.zip ec2-user@ec2_instance_public:/home/ec2-user
scp /path/to/Origination_PAM_v202104.01.zip ec2-user@ec2_instance_public:/home/ec2-user
```

> Other than these five files, you also have *BPM.zip* from *Temenos*, you'll use it locally,
> there's no need to copy it to the instance.

#### Connect to the EC2 Instance

Connect to the created instance using ssh (note *ec2_instance_public*):

```shell
ssh -i /path/to/private.pem ec2-user@ec2_instance_public
```

#### Install Packages

```shell
sudo dnf upgrade -y
sudo rpm -U https://repo.mysql.com/mysql80-community-release-el8-1.noarch.rpm
sudo dnf install mysql unzip java-1.8.0-openjdk-devel -y
```

#### Install Maven

```shell
curl https://dlcdn.apache.org/maven/maven-3/3.8.3/binaries/apache-maven-3.8.3-bin.tar.gz \
    -o apache-maven-3.8.3-bin.tar.gz
sudo tar xzvf apache-maven-3.8.3-bin.tar.gz -C /opt
rm apache-maven-3.8.3-bin.tar.gz
sudo ln -s /opt/apache-maven-3.8.3/bin/mvn /usr/local/bin/mvn
```

#### Populate Database

Execute the following commands, note the *mysql_dns_address* and *your_user* place holders,</br>
Note that we're making use of a file you were instructed to download at the start of this document.

```shell
# unzip and prepare path
mkdir ~/rhpam-7.9.0-add-ons
unzip ~/rhpam-7.9.0-add-ons.zip -d ~/rhpam-7.9.0-add-ons
cd ~/rhpam-7.9.0-add-ons
unzip rhpam-7.9.0-migration-tool.zip
cd rhpam-7.9.0-migration-tool/ddl-scripts/mysql5
# run scripts using mysql client on remote instance, requires mysql client
mysql -h mysql_dns_address -u your_user -p jbpm < mysql-jbpm-amend-auto-increment-procedure.sql
mysql -h mysql_dns_address -u your_user -p jbpm < mysql5-jbpm-schema.sql
mysql -h mysql_dns_address -u your_user -p jbpm < quartz_tables_mysql.sql
mysql -h mysql_dns_address -u your_user -p jbpm < task_assigning_tables_mysql.sql
# cleanups (optional)
cd ~
rm -r rhpam-7.9.0-add-ons
rm ~/rhpam-7.9.0-add-ons.zip
# verify
mysql -h mysql_dns_address -u your_user -p jbpm -e "show tables"
```

#### Install JBoss

The following installation will prompt you for configuring *JBoss* installation. i.e. *user name*,
*password*.</br>
It's all pretty basic, just note one **very important part**:</br>
the installation folder default will be `/root/EAP-7.3.0`, set it to `/opt/EAP-7.3.0`.

```shell
sudo java -jar ~/jboss-eap-7.3.0-installer.jar -console
```

If you want to verify *JBoss* installation, run it as a standalone *JBoss* server:

```shell
sudo /opt/EAP-7.3.0/bin/standalone.sh -b 0.0.0.0
```

and open browser from your local station (note rhpam_public_ip):</br>
`http://rhpam_public_ip:8080/`.

Control+c to end the standalone server.

```shell
# cleanups (optional)
rm ~/jboss-eap-7.3.0-installer.jar
```

#### Install RHPAM

The following installation will ask you where do you have *JBoss* installed,</br>
use the installation folder you selected when installing *JBoss*, `/opt/EAP-7.3.0`.

```shell
sudo java -jar ~/rhpam-installer-7.9.0.jar -console
# cleanups (optional)
rm ~/rhpam-installer-7.9.0.jar
```

#### Configure MySQL Backend

Extract the downloaded *MySQL* connector and add it as a *JBoss* module:

```shell
# extract the connector
unzip ~/mysql-connector-java-8.0.25.zip -d ~
# create module path
sudo mkdir -p /opt/EAP-7.3.0/modules/system/layers/base/com/mysql/main
cd /opt/EAP-7.3.0/modules/system/layers/base/com/mysql/main
# copy module
sudo cp ~/mysql-connector-java-8.0.25/mysql-connector-java-8.0.25.jar .
```

Create the module file:

```shell
sudo bash -c 'cat << EOF > module.xml
<module xmlns="urn:jboss:module:1.5" name="com.mysql">
    <resources>
        <resource-root path="mysql-connector-java-8.0.25.jar"/>
    </resources>
    <dependencies>
        <module name="javax.api"/>
        <module name="javax.transaction.api"/>
    </dependencies>
</module>
EOF'
```

Cleanup:

```shell
cd ~
rm -r ~/mysql-connector-java-8.0.25
rm ~/mysql-connector-java-8.0.25.zip
```

Run *JBoss* standalone server:

```shell
sudo /opt/EAP-7.3.0/bin/standalone.sh -b 0.0.0.0
```

Open another cli and connect using ssh to the instance from another session.</br>
Once connected to the instance, run the following commands to connect to the running *JBoss* and
instruct it to install the *MySQL* connector's dependencies:

```shell
# connect to JBoss
sudo /opt/EAP-7.3.0/bin/jboss-cli.sh --connect
# install dependencies
module add --name=com.mysql \
    --resources=/opt/EAP-7.3.0/modules/system/layers/base/com/mysql/main/mysql-connector-java-8.0.25.jar \
    --dependencies=javax.api,javax.transaction.api
# leave cli
exit
```

> You can close the second session and press Control+c in the first session to stop *JBoss*
> standalone server.

Update the configuration file to use the *MySQL* connector:

```shell
cd /opt/EAP-7.3.0/standalone/configuration
sudo cp standalone-full.xml standalone-full.xml.bak
sudo vi standalone-full.xml
```

Search string (using /) for `urn:jboss:domain:datasources`.</br>
expect to find the element:

```xml
<subsystem xmlns="urn:jboss:domain:datasources:5.0">
```

type `i` to enter into *insert mode*,</br>
under `<datasources><drivers>` add the folowwing node (watch identation):

```xml
                    <driver name="mysql" module="com.mysql"/>
```

under `<datasources>` add the following node, please note the *mysql_instance_name*,</br>
and the **database**'s *user-name* and *password* (watch the identation):

```xml
                <datasource jndi-name="java:/jbpmDS" pool-name="jbpmDS">
                    <connection-url>jdbc:mysql://mysql_instance_name:3306/jbpm</connection-url>
                    <driver>mysql</driver>
                    <pool>
                        <max-pool-size>200</max-pool-size>
                    </pool>
                    <security>
                        <user-name>rhadmin</user-name>
                        <password>redhat123#</password>
                    </security>
                    <validation>
                        <valid-connection-checker class-name="org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLValidConnectionChecker"/>
                        <validate-on-match>true</validate-on-match>
                        <background-validation>false</background-validation>
                        <exception-sorter class-name="org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLExceptionSorter"/>
                    </validation>
                    <timeout>
                        <idle-timeout-minutes>30</idle-timeout-minutes>
                    </timeout>
                </datasource>
```

Press `esc` to get back to *visual mode*.</br>
Search string (using /) for `<system-properties>`.</br>
type `i` to enter into *insert mode*,</br>
add the following property nodes (watch the identation):

```xml
        <property name="org.kie.server.persistence.ds" value="java:/jbpmDS"/>
        <property name="org.kie.server.persistence.dialect" value="org.hibernate.dialect.MySQL5InnoDBDialect"/>
```

Press `esc` to get back to *visual mode*.</br>
Type `:wq` (and press enter) to *write and quit*.

#### Start RHPAM at startup

```shell
sudo bash -c 'cat << EOF > /etc/systemd/system/jbosseap.service
[Unit]
Description=JBoss EAP Service

[Service]
ExecStart=/opt/EAP-7.3.0/bin/standalone.sh -c standalone-full.xml -b 0.0.0.0
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl start jbosseap.service
sudo systemctl enable jbosseap.service
```

Give it a couple of minutes to start up and verify RHPAM,</br>
from your local browser (note ec2_instance_public):</br>
`http://ec2_instance_public:8080/business-central`

Use the user name and password you created while installing *RHPAM*0

#### Build and Deploy Temenos projects

##### Add lib GetTasksCustomAPI

```shell
unzip ~/Origination_PAM_v202104.01.zip -d ~/origination
cd origination/Binaries
sudo cp GetTasksCustomAPI-1.0.jar /opt/EAP-7.3.0/standalone/deployments/kie-server.war/WEB-INF/lib
# cleanup (optional)
cd ~
rm -r origination
rm Origination_PAM_v202104.01.zip
```

Restart the server and exit the ssh connection:

```shell
sudo systemctl restart jbosseap.service
exit
```

##### Build and Upload artifact OriginationWorkItem

> This step is to be performed on your local station.

First, prepare the project for build and deployment.

```shell
unzip /path/to/BPM.zip -d ~
cd ~/BPM/Java
find . -name 'pom.xml' | xargs sed -i 's/http:\/\//https:\/\//g'
sed -i -e '/<distributionManagement>/,/<\/distributionManagement>/d' pom.xml
mvn package -DskipTests=true
```

Now you need to upload the artifact.

- From your local browser login to the *Business Central* (note ec2_instance_public):
  `http://ec2_instance_public:8080/business-central`.
- Click the *Settings* icon and click *Artifacts*.
- Click *Upload* and navigate to *~/BPM/Java/pom.xml* and click *Upload*.
- Click *Upload* again and navigate to *~/BPM/Java/OriginationWorkItem/target/OriginationWorkItem-2021.01.00.jar*
  and click *Upload*.
- Click *Settings* again, and this time click *Custom Tasks Administration* (at the bottom).
- Click *Add Custom Task* and navigate to *~/BPM/Java/OriginationWorkItem/target/OriginationWorkItem-2021.01.00.jar*
  and click *Upload*.
- Scroll down and look for the added task *OriginationServiceTask*, turn it on.

Get back to your shell for cleanup (optional):

```shell
cd ~
rm -r ~/BPM
```

##### Import and Deploy Origination project

Extract your local copy of the *Origination* project.</br>
You'll need to modify the sources and create a git repository for the deployment process.

> Please note that you'll need to push the project to a remote repository that is accessible over
> the internet. A private one is preferable.</br>
> Also note that the master branch needs to be named *master*.
> You can, and should, delete the remote repository after importing.

First, prepare the project for build and push it.

```shell
unzip /path/to/Origination_PAM_v202104.01.zip -d ~/origination
cd ~/origination/
unzip Origination_PAM_Source_v202104.01.zip -d sources
cd sources
sed -i 's/http:\/\//https:\/\//g' pom.xml
git init -b master
git add .
git commit -m "Onboarding"
git remote add origin <your-repo-goes-here>
git push -u origin master
```

Now, you need to import the project:

- From your local browser get back to (note ec2_instance_public):
  `http://ec2_instance_public:8080/business-central`.
- From the main page, click *Projects* in the bottom part of the *Design* tile and select *MySpace*.
- Click *Import Project* and paste in the *Git* repo for your modified version of the *Origination*
  project.
- Select the *Origination* project and press *Ok*.
- Enter the *Settings* tab in the project, and click the *Custom Tasks* menu on the left.
- Look for the task *OriginationServiceTask*, install it.
- You can verify the action by clicking the *Deployments* menu on the left, and then the
  *Work Item Handlers*, you should see a handler named *OriginationServiceTask* instantiating
  *com.temenos.infinity.OriginationWorkItemHandler*.
- Click *Deploy* at the upper right corner to deploy the project.

Get back to your shell for cleanup (optional):

```shell
cd ~
sudo rm -r ~/origination/
```

### Create an RHPAM AMI

After creating your *EC2* instance and installing/configuring *JBoss* and *RHPAM*,</br>
you should create an *Amazon Machine Image (AMI)* which is, as the suggests and image of your
machine, meaning your instance.</br>
Creating the *AMI* serves two purposes, not only will it save you the trouble of reinstalling, but
it'll also play a major part when it comes to autoscaling.</br>
*AMI*s are all around us, if you remember, we also started our *EC2* instance from an
*AMI for Red Hat Enterprise Linux 8*, aka `ami-0b0af3577fe5e3532`.</br>
Each *AMI* has its unique id, and can be used privately or deployed to [Amazon's Marketplace][20].

Creating an *AMI* is pretty straight-forward, from the *Instances* dashboard in the *EC2* console,</br>
select your instance, click *Actions* -> *Image and templates* -> *Create image*.

Create an *AMI* with the following characteristics:

```text
Image name: temenos-rhpam-mysql-ami
Image description: Temenos RHPAM 7.9.0 based on JBoss 7.3.0 backed by RDS MySQL
Tags: Name=Temenos RHPAM 7.9 with MySQL
```

The *AMI* takes some time to spin up, but once it becomes available, you can use it to
create *EC2* instances with your pre-configured *RHPAM*.

And of course, if you're a [AWS CLI][2] user:

```shell
aws ec2 create-image \
    --instance-id <the-id-of-the-ec2-instance-created> \
    --name temenos-rhpam-mysql-ami \
    --description "Temenos RHPAM 7.9.0 based on JBoss 7.3.0 backed by RDS MySQL" \
    --tag-specifications "ResourceType=image, Tags=[{Key=Name, Value=Temenos RHPAM 7.9 with MySQL}]"
```

### Auto Scaling

---
TBD

---

<!-- Links -->
[0]: https://aws.amazon.com/
[1]: https://console.aws.amazon.com/
[6]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html
[7]: https://www.redhat.com/en/enterprise-linux-8
[8]: https://www.redhat.com/en/technologies/jboss-middleware/process-automation-manager
[9]: https://www.redhat.com/en/technologies/jboss-middleware/application-platform
[10]: https://aws.amazon.com/ec2/autoscaling/
[11]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions
[13]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Tutorials.WebServerDB.CreateVPC.html
[14]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
[18]: https://access.redhat.com/articles/3405381
[19]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
[20]: https://aws.amazon.com/marketplace
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
