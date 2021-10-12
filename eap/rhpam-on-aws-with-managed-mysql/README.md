# Deploy RHPAM 7.9 with JBoss EAP 7.3 on AWS with MySQL backend

## What's this

In this document, we will walk through the preparation and installation of *RHPAM* backed with a
managed/unmanaged *MySQL* instance using [AWS][0].

## A brief walkthrough and some glossary

Using [Amazon Web Services][0] we will create an isolated cloud environment with the
[Virtual Private Cloud (VPC)][3] service.</br>
Connected to our *VPC*, we'll have a [Relational Database Service (RDS)][4] instance hosting a
*MySQL* database, we will also have an [Elastic Compute Cloud (EC2)][5] instance running an
[Amazon Machine Image (AMI)][6] based on [Red Hat Enterprise Linux 8][7].</br>
Installed on our *EC2 instance* we'll have [Red Hat Process Automation Manager (RHPAM)][8] running
on [Red Hat JBoss Enterprise Application Platform (JBoss EAP)][9] and using our *RDS instance* as
the backend *MySQL* database.</br>
The *MySQL* instance will reside inside a *private designated subnet* and will not be accessible
from the internet,</br>
the *RHPAM* instance will reside inside a *public designated subnet* and will be accessible from
the internet.</br>
Once done, we'll create a custom [Amazon Machine Image (AMI)][6], which will be later used for
[Auto Scaling][10].

## Let's dive in

You can use [AWS Console][1] to access all the services required for this document.

### Prerequisite: Create or import a Key-Pair

You'll use the key-pair to connect to instances remotely via ssh.
You can use the same key for multiple instances/projects,</br>
so I wouldn't name it anything obligating.

If you're a [AWS CLI][2] user you can use
[scripts/aws_create_import_keypair.sh](scripts/aws_create_import_keypair.sh) to create/import your
ssh key-pair.</br>
Otherwise, it can be done via the *EC2* console.

If you create a new *Key-Pair*,</br>
once created, you will be able to download the private key to your local station.

If you import an existing key,</br>
make sure to paste in the **public** key and not the private one.

> If you create a new key with *aws*, please consider `chmod 400` the downloaded private key file.

### Prerequisite: Download files

From your local station download the following files:

- [RHPAM 7.9 addons zip archive][12]
- [RHPAM installer jar][15]
- [JBoss EAP 7.3.3 installer jar][16]
- [MySQL connector for Java zip archive][17]

> Please take a look at [this matrix][18] before attempting to download other versions.

---
If you're an [AWS CLI][2] user, you can use
[scripts/aws_create_environment.sh](scripts/aws_create_environment.sh) and skip ahead to the
[Prepare EC2 Instance](#prepare-ec2-instance) section.

If you decide to opt for the manual setup,</br>
please note that you can probably use the *VPC Wizard* and save a couple of steps described in
this document.</br>
You can follow [this tutorial][13] which achieves a similar setup to what we're going for here.

---

### Create an Elastic IP

The *Elastic IP* will be attached later on to our *NAT Gateway* to allow our instances to access the
internet.</br>
Allocate an Elastic IP address with the following characteristics:

```text
Network Border: <your-selected-region>
Tags: Name=Temenos NAT-GW Elastic IP
```

> Please see [this guide][11] and select the *Region Code* most suited for you, i.e. *us-east-1*.

### Create the VPC

The *Virtual Private Cloud* will be the base of our isolated cloud environment</br>
Create a *VPC* with the following characteristics:

```text
Name: Temenos RHPAM VPC
IPv4: 10.0.0.0/16
```

### Create the Subnets

For this runbook, we'll create **three** *Subnets*.</br>
The first one will be attached later on our *Internet Gateway* to be accessible over the internet.</br>
This subnet will host our *RHPAM* instance.</br>
The other **two** subnets will **not be** attached to an *Internet Gateway* and therefore will not
be accessible over the internet.</br>
These subnets will host our *MySQL* instance.

> Please note, *MySQL* instance requires two private/public subnets in two different [availability zones][11].

Create **three** *Subnets*, one public and two private,</br>
each in a different availability zone, with the following characteristics,</br>
replace the *zone-x* with real availability zones. i.e. *us-east-1a*, *us-east-1-b*, *us-east-1c*:

*public zone a*:

```text
VPC: <select the vpc you created>
Subnet Name: Temenos RHPAM Public Subnet <zone-a>
Availability Zone: <zone-a>
IPv4 CIDR block: 10.0.1.0/24

*private zone b*:

```text
VPC: <select the vpc you created>
Subnet Name: Temenos RHPAM Private Subnet <zone-b>
Availability Zone: <zone-b>
IPv4 CIDR block: 10.0.2.0/24
```

*private zone c*:

```text
VPC: <select the vpc you created>
Subnet Name: Temenos RHPAM Private Subnet <zone-c>
Availability Zone: <zone-c>
IPv4 CIDR block: 10.0.3.0/24
```

### Create a NAT Gateway

The *NAT Gateway* will allow our instances to access the internet.</br>
Create a *NAT Gateway* with the following characteristics:

```text
Name: Temenos RHPAM NAT Gateway
Subnet: <select the public designated subnet you created>
Elastic IP allocation ID: <select the elastic ip you created>

```

### Create an Internet Gateway

The *Internet Gateway* will allow us to make our *RHPAM* instance accessible over the internet.</br>
Subnets attached to this gateway, are implicitly public.</br>
Create an *Internet Gateway* with the following characteristics:

```text
Name: Temenos RHPAM Internet Gateway
```

Select the new gateway and press *Actions* -> *Attach*,</br>
and attach the gateway to the vpc you created.

### Create the Route Table

For this runbook, we need to create **two** *Route Tables*.</br>
The first one will be attached to the *NAT Gateway* we created earlier in this document,</br>
it will act as our **main** *Route Table* and will be adhered to by all the subnets.

The second one will be attached to the *Internet Gateway* you created earlier in this document,</br>
it will be explicitly set to the *Subnet* we designated as a public one.

Create a *Route Table* with the following characteristics:

```text
Name: Temenos RHPAM NAT Route Table
VPC: <select the vpc you created>
Tags: Name=Temenos RHPAM NAT Route Table
```

Press *Edit Routes* -> *Add Route*,</br>
and add a route with the following characteristics:

```text
Destination: 0.0.0.0/0
Target: <select the nat gateway you created>
```

Press *Actions* -> *Set main route table*,</br>
to make the *NAT* table as the **main** table.</br>
While you're at it, feel free to delete the table that was marked as main for your *VPC* before the
new one, it was created by default, it has no more usage.

Create another *Route Table* with the following characteristics:

```text
Name: Temenos RHPAM Internet Route Table
VPC: <select the vpc you created>
Tags: Name=Temenos RHPAM Internet Route Table
```

Press *Edit Routes* -> *Add Route*,</br>
and add a route with the following characteristics:

```text
Destination: 0.0.0.0/0
Target: <select the internet gateway you created>
```

Inside the route table, go to the *Subnet Association* tab,</br>
and associate this table to the public designated *Subnet* you created.

### Create the Security Groups

The security groups will set the network rules for our instances.</br>
Create **two** Security Groups with the following characteristics:

One group designated to be used by the *RHPAM* frontend instance:

```text
Name: rhpam-jboss-front
Description: Temenos RHPAM JBoss Front Security Group
VPC: <select the vpc you created>
```

Add the following Inbound Rules to the frontend group:

```text
Type: Custom TCP -> Port range: 8080 -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Business Central Http
Type: Custom TCP -> Port range: 8443 -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Business Central Https
Type: Custom TCP -> Port range: 9990 -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Administration GUI
Type: SSH -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Connection SSH

```

Add the following Tag to the frontend group:

```text
Name=Temenos RHPAM JBoss Front Security Group
```

The second group is designated to be used by the *MySQL* backend instance:

```text
Name: rhpam-mysql-back
Description: Temenos RHPAM MySQL Back Security Group
VPC: <select the vpc you created>
```

And add the following Inbound Rules to the backend group:

```text
Type: MYSQL/Aurora -> Source: <select the frontend security group> -> Description: Connection MySQL
Type: SSH -> Source: <select the frontend security group> -> Description: SSH Connection
```

Add the following Tag to the backend group:

```text
Tags: Temenos RHPAM MySQL Back Security Group
```

### Create the RDS DB Subnet Group

---
If you prefer an unamaged *MySQL EC2 Instance*, you can reffer to
[manuals/unmanaged-mysql-rhel8.md](manuals/unmanaged-mysql-rhel8.md).</br>
Once you're done, you can skip this step and go directly to the
[Create an EC2 Instance for RHPAM](#create-an-ec2-nstance-for-rhpam) section.

---

Please select your [availability zones][11] you created the private designated subnets with.</br>
Create a *DB Subnet Group* with the following characteristics:

```text
Name: rhpam-mysql-subnet-group
Description: Temenos RHPAM MySQL Subnet Group
VPC: <select the vpc you created>
Availability Zones: <select the availability zones you created the private subnets with>
Subnets: <select the private designated subnets you created>
Tags: Name=Temenos RHPAM MySQL Subnet Group
```

### Create a MySQL DB Managed RDS Instance

> This step is not required if you're running an unmanaged *MySQL* instance.

Please chose a *db instance class* [here][19].
Create a *Database Instance* with the following characteristics (note and change the username and
password):

```text
Creation method: Standard create
Engine Type: MySQL
Version: 8.0.25
Instance Identifier: rhpam-mysql-db
Master username: rhadmin
Master password: redhat123#
DB instance class: <your chosen instance type>
Virtual private cloud: <select the vpc you created>
Subnet group: <select the subnet group you created>
VPC security group: <select the rhpam-mysql-subnet-group you created>
Initial database name: jbpm
Log exports: Error log
Enable auto minor version upgrade: unchecked
```

### Create an EC2 Instance for RHPAM

Create an *EC2 Instance* from the base *AMI for Red Hat Enterprise Linux 8*.</br>
Use the unsubscribed *Red Hat Enterprise Linux 8* bare installation from the *EC2 AMI* list in the
wizard.</br>
For searching reference, or if you're using the *cli*, the *AMI* id for a 64x86 *AMI* is
`ami-0b0af3577fe5e3532`.

> Note that you will need to select an [EC2 Instance Type][14] for your instance.</br>
> The minimum requirements are **2CPUs and 2GiB memory**.

Configure the *EC2 Instance* with the following characteristics:

```text
Network: <select the vpc you created>
Subnet: <select the public subnet you created>
Auto-assign Public IP: Enable
Security Groups: <select the rhpam-jboss-front group you created>
Tags: Name=Temenos RHPAM JBoss
Key-Pair: <the name of the key-pair you created/imported>
```

### Prepare EC2 Instance

> Note the database can take a couple of minutes to spin up, you might need to wait for it to
> become available.

#### Grab IP Addresses

Once the *EC2 Instance* is up and available, grab its public IP or DNS name from the console</br>
Or if you're a [AWS CLI][2] user:

```shell
aws ec2 describe-instances \
    --instance-ids <the-id-of-the-ec2-instance-you-just-created> \
    --query Reservations[].Instances[].[PublicDnsName,PublicIpAddress]
```

> If you're running an unmanaged instance of the database,
> you can skip the part about obtaining the endpoint address, you already have the IP address.

Once the *RDS Instance* is up and available, grab its endpoint address from the console.</br>
Or if you're a [AWS CLI][2] user:

```shell
aws rds describe-db-instances \
    --db-instance-identifier rhpam-mysql-db \
    --query DBInstances[].Endpoint.Address --output text
```

#### Copy files

Use `scp` to copy the files you downloaded at the start of this document over ssh (note
*ec2_instance_public*):

```shell
scp /path/to/rhpam-7.9.0-add-ons.zip ec2-user@ec2_instance_public:/home/ec2-user
scp /path/to/jboss-eap-7.3.0-installer.jar ec2-user@ec2_instance_public:/home/ec2-user
scp /path/to/rhpam-installer-7.9.0.jar ec2-user@ec2_instance_public:/home/ec2-user
scp /path/to/mysql-connector-java-8.0.25.zip ec2-user@ec2_instance_public:/home/ec2-user
```

#### Connect to the EC2 Instance

Connect to the created instance using ssh (note *ec2_instance_public*):

```shell
ssh -i /path/to/private.pem ec2-user@ec2_instance_public
```

#### Update Packages

```shell
sudo dnf upgrade -y
```

#### Install MySQL Client

Install *MySQL* for database connectivity:

```shell
sudo rpm -Uvh https://repo.mysql.com/mysql80-community-release-el8-1.noarch.rpm
sudo sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/mysql-community.repo
sudo dnf --enablerepo=mysql80-community install mysql.x86_64
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

#### Install JDK

```shell
sudo dnf install java-1.8.0-openjdk-devel.x86_64 -y
```

#### Install Maven

```shell
curl https://dlcdn.apache.org/maven/maven-3/3.8.3/binaries/apache-maven-3.8.3-bin.tar.gz \
    -o apache-maven-3.8.3-bin.tar.gz
sudo tar xzvf apache-maven-3.8.3-bin.tar.gz -C /opt
rm apache-maven-3.8.3-bin.tar.gz
sudo ln -s /opt/apache-maven-3.8.3/bin/mvn /usr/local/bin/mvn
```

#### Install JBoss

The following installation will prompt you for configuring *JBoss* installation. i.e. *user name*,
*password*.</br>
It's all pretty basic, just note the installation folder, i.e. */home/ec2-user/EAP-7.3.0*, we'll
need it later on.

```shell
java -jar ~/jboss-eap-7.3.0-installer.jar -console
```

If you want to verify *JBoss* installation, run it as a standalone *JBoss* server:

```shell
/home/ec2-user/EAP-7.3.0/bin/standalone.sh -b 0.0.0.0
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
use the installation folder you noted when installing *JBoss*.

```shell
java -jar ~/rhpam-installer-7.9.0.jar -console
# cleanups (optional)
rm ~/rhpam-installer-7.9.0.jar
```

#### Configure MySQL Backend

Extract the downloaded *MySQL* connector and add it as a *JBoss* module:

```shell
# extract the connector
unzip ~/mysql-connector-java-8.0.25.zip -d ~
# create module path
cd /home/ec2-user/EAP-7.3.0/modules/system/layers/base/com/
mkdir -p mysql/main
cd mysql/main
# copy module
cp ~/mysql-connector-java-8.0.25/mysql-connector-java-8.0.25.jar .
```

Create the module file:

```shell
cat << EOF > module.xml
<module xmlns="urn:jboss:module:1.5" name="com.mysql"> 
    <resources>
        <resource-root path="mysql-connector-java-8.0.25.jar"/>
    </resources>
    <dependencies>
        <module name="javax.api"/>
        <module name="javax.transaction.api"/>
    </dependencies>
</module>
EOF
```

Cleanup:

```shell
cd ~
rm -r ~/mysql-connector-java-8.0.25
rm ~/mysql-connector-java-8.0.25.zip
```

Run *JBoss* standalone server:

```shell
/home/ec2-user/EAP-7.3.0/bin/standalone.sh -b 0.0.0.0
```

Open another cli and connect using ssh to the instance from another session.</br>
Once connected to the instance, run the following commands to connect to the running *JBoss* and
instruct it to install the *MySQL* connector's dependencies:

```shell
# connect to JBoss
/home/ec2-user/EAP-7.3.0/bin/jboss-cli.sh --connect
# install dependencies
module add --name=com.mysql \
    --resources=/home/ec2-user/EAP-7.3.0/modules/system/layers/base/com/mysql/main/mysql-connector-java-8.0.25.jar \
    --dependencies=javax.api,javax.transaction.api
# leave cli
exit
```

> You can close the second session and press Control+C in the first session to stop *JBoss*
> standalone server.

Update the configuration file to use the *MySQL* connector:

```shell
cd /home/ec2-user/EAP-7.3.0/standalone/configuration
cp standalone-full.xml standalone-full.xml.bak
vi standalone-full.xml
```

Search string (using /) for `urn:jboss:domain:datasources`.</br>
expect to find the element:

```xml
<subsystem xmlns="urn:jboss:domain:datasources:5.0">
```

press `i` to enter into *insert mode*,</br>
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
add the following property nodes (watch the identation):

```xml
        <property name="org.kie.server.persistence.ds" value="java:/jbpmDS"/>
        <property name="org.kie.server.persistence.dialect" value="org.hibernate.dialect.MySQL5InnoDBDialect"/>
```

Press `esc` to get back to *visual mode*.</br>
Press `:wq` (and enter) to write and quit.

Get back home and run the server:

```shell
cd ~
/home/ec2-user/EAP-7.3.0/bin/standalone.sh -c standalone-full.xml -b 0.0.0.0
```

To verify RHPAM Installation, from your local browser (note rhpam_public_ip):</br>
`http://rhpam_public_ip:8080/business-central`

Use the user name and password you created with *RHPAM* installation.

#### Deploy BPM and ORIGINATOR

---
Under construction.

---

<!-- Links -->
[0]: https://aws.amazon.com/
[1]: https://console.aws.amazon.com/
[2]: https://aws.amazon.com/cli/
[3]: https://console.aws.amazon.com/vpc/
[4]: https://console.aws.amazon.com/rds/
[5]: https://console.aws.amazon.com/ec2/
[6]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html
[7]: https://www.redhat.com/en/enterprise-linux-8
[8]: https://www.redhat.com/en/technologies/jboss-middleware/process-automation-manager
[9]: https://www.redhat.com/en/technologies/jboss-middleware/application-platform
[10]: https://aws.amazon.com/ec2/autoscaling/
[11]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions
[12]: https://developers.redhat.com/content-gateway/file/rhpam-7.9.0-add-ons.zip
[13]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Tutorials.WebServerDB.CreateVPC.html
[14]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
[15]: https://developers.redhat.com/content-gateway/file/rhpam-installer-7.9.0.jar
[16]: https://developers.redhat.com/content-gateway/file/jboss-eap-7.3.3-installer.jar
[17]: https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-java-8.0.25.zip
[18]: https://access.redhat.com/articles/3405381
[19]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
