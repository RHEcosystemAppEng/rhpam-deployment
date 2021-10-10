# Deploy RHPAM 7.9 with JBoss EAP 7.3 on AWS with MySQL backend

## What's this

This document exemplifies a couple of approaches for deploying RHPAM backed with MySQL on [AWS][0].</br>
From the operation standpoint, the same can be achieved using either [AWS Console][1] or [AWS CLI][2].</br>
We will explain how to run a managed/unmanaged MySQL instance, as well as how to use prepared images (AMI),
and manual installations.</br>
We will also touch base in regards to [Auto Scaling][10].

## A brief walkthrough and some glossary

Using [Amazon Web Services][0] we will create an isolated cloud environment using [Virtual Private Cloud (VPC)][3].</br>
Connected to our *VPC*, will have [Relational Database Service (RDS)][4] instance hosting a *MySQL*
database and an [Elastic Compute Cloud (EC2)][5] instance running an [Amazon Machine Image (AMI)][6]
based on [Red Hat Enterprise Linux 8][7].</br>
Installed on our *EC2 instance* we'll have [Red Hat Process Automation Manager (RHPAM)][8] running on
[Red Hat JBoss Enterprise Application Platform (JBoss EAP)][9] and using our *RDS instance* as the
backend *MySQL* database.

## Let's dive in

---
If you're an [AWS CLI][2] user, you can use
[scripts/aws_create_environment.sh](scripts/aws_create_environment.sh) and skip to the
[Populate the Database](#populate-the-database) section.</br>
You can also use [scripts/create_import_keypair.sh](scripts/create_import_keypair.sh) to create/import your ssh key-pair.

---

### Prerequisite: Create or import a Key-Pair

The key pair allows you to connect remotely via ssh to instances.
You can use the same key for multiple instances/projects, so I wouldn't name it anything obligating.

If you create a new *Key-Pair*,</br>
once created, you will be able to download the private key to your local station.

If you import an existing key,</br>
make sure to paste in the **public** key and not the private one.

> If you create a new key, please consider 'chmod 400' the downloaded private key file.

### Create the VPC

Create a *VPC* with the following characteristics:

```text
Name: Temenos RHPAM VPC
IPv4: 10.0.0.0/16
```

### Create the Subnets

> Please note, *MySQL* managed instance requires two subnets in two different [availability zones][11].

For our example, create **two** *Subnets*, one in each availability zone,
with the following characteristics:

A public designated subnet in both zones:</br>
*public zone a*:

```text
VPC: <select the vpc you created>
Subnet Name: Temenos RHPAM Public Subnet **<zone a>**
Availability Zone: <zone-**a**[11] of your choosing>
IPv4 CIDR block: 10.0.1.0/24
```

*public zone b*:

```text
VPC: <select the vpc you created>
Subnet Name: Temenos RHPAM Public Subnet **<zone b>**
Availability Zone: <zone-**b**[11] of your choosing>
IPv4 CIDR block: 10.0.2.0/24
```

Select the **public** subnets and press *Actions* -> *Modify auto-assign IP settings*.</br>
Check the *Enable auto-assign public IPv4 address* checkbox and save.

### Create an Internet Gateway

Create an *Internet Gateway* with the following characteristics:

```text
Name: Temenos RHPAM Internet Gateway
```

Select the new gateway and press *Actions* -> *Attach*.</br>
Attach the gateway to the vpc you created.

### Create the Route Table

Create a *Route Table* with the following characteristics:

```text
Name: Temenos RHPAM Route Table
VPC: <select the vpc you created>
Tags: Name=Temenos RHPAM Route Table
```

Press *Edit Routes* -> *Add Route* and a route with the following characteristics:

```text
Destination: 0.0.0.0/0
Target: <select the internet gateway you created>
```

Press *Actions* -> *Edit subnet associations* and select all of the public subnets you created.

### Create the Security Groups

Create *two* Security Groups with the following characteristics:

One group designated to use with *RHPAM* frontend:

```text
Name: rhpam-front
Description: Temenos RHPAM Front
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
Name=Temenos RHPAM Front
```

The second group is designated to use the *MySQL* backend:

```text
Name: rhpam-mysql-back
Description: Temenos RHPAM MySQL Back
VPC: <select the vpc you created>
```

And add the following Inbound Rules to the backend group:

```text
Type: MYSQL/Aurora -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: Connection MySQL
Type: SSH -> Source: Anywhere-IPv4 (0.0.0.0/0) -> Description: SSH Connection
```

Add the following Tag to the backend group:

```text
Tags: Temenos RHPAM MySQL Back
```

### Create the RDS DB Subnet Group

---
If you prefer an unamaged *MySQL EC2 Instance*, you can reffer to [manuals/unmanaged-mysql-rhel8.md](manuals/unmanaged-mysql-rhel8.md).</br>
Once you're done, you can skip this step and go directly to the [Populate the Database](#populate-the-database) section.

---

Create a *DB Subnet Group* with the following characteristics:

```text
Name: rhpam-mysql-subnet-group
Description: Temenos RHPAM MySQL Subnet Group
VPC: <select the vpc you created>
Availability Zones: <select the availability zones you created the subnets with>
Subnets: <select the subnets you created>
Tags: Name=Temenos RHPAM MySQL Subnet Group
```

### Create a MySQL DB Managed RDS Instance

---
If you prefer an unamaged *MySQL EC2 Instance*, you can reffer to [manuals/unmanaged-mysql-rhel8.md](manuals/unmanaged-mysql-rhel8.md).</br>
Once you're done, you can skip this step and go directly to the [Populate the Database](#populate-the-database) section.

---

Create a *Database Instance* with the following characteristics:

```text
Creation method: Standard create
Engine Type: MySQL
Version: 8.0.25
Instance Identifier: rhpam-mysql-db
Master username: rhadmin
Master password: redhat123#
DB instance class: <select from here https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html>
Virtual private cloud: <select the vpc you created>
Subnet group: <select the subnet group you created>
Initial database name: jbpm
Log exports: Error log
Enable auto minor version upgrade: unchecked
```

### Populate the Database

> Note that the following actions require a local installation of the *MySQL client*.

From your local station download the [rhpam addons zip archive]][1], note *mysql_elastic_ip*:

```shell
# unzip and prepare path
mkdir ~/rhpam-7.9.0-add-ons
unzip /path/to/rhpam-7.9.0-add-ons.zip -d ~/rhpam-7.9.0-add-ons
cd ~/rhpam-7.9.0-add-ons
unzip rhpam-7.9.0-migration-tool.zip
cd rhpam-7.9.0-migration-tool/ddl-scripts/mysql5
# runs scripts using mysql client on remote instance, requires mysql client
mysql -h mysql_elastic_ip -u root -p jbpm < mysql-jbpm-amend-auto-increment-procedure.sql
mysql -h mysql_elastic_ip -u root -p jbpm < mysql5-jbpm-schema.sql
mysql -h mysql_elastic_ip -u root -p jbpm < quartz_tables_mysql.sql
mysql -h mysql_elastic_ip -u root -p jbpm < task_assigning_tables_mysql.sql
# cleanups (optional)
cd ~
rm -r rhpam-7.9.0-add-ons (optional)
rm /path/to/rhpam-7.9.0-add-ons.zip (optional)
# verify
mysql -h mysql_elastic_ip -u root -p jbpm -e "show tables"
```

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
