# Deploy RHPAM 7.9 with JBoss EAP 7.3 on AWS with MySQL backend

## What's this

This document exemplifies a couple of approaches for deploying RHPAM backed with MySQL on [AWS][0].</br>
From the operation standpoint, the same can be achieved using either [AWS Console][1] or [AWS CLI][2].</br>
We will explain how to run a managed/unmanaged MySQL instance, as well as how to use prepared images (AMI),
and manual installations.</br>
We will also touch base in regards to [Auto Scaling][10].

## A brief walkthrough and some glossary

Using [Amazon Web Services][0] we're going to create an isolated cloud environment using [Virtual Private Cloud (VPC)][3].</br>
Connected to our *VPC*, will have [Relational Database Service (RDS)][4] instance hosting a *MySQL* database and an [Elastic Compute Cloud (EC2)][5] instance running an [Amazon Machine Image (AMI)][6] based on [Red Hat Enterprise Linux 8][7].</br>
Installed on our *EC2 instance* will have [Red Hat Process Automation Manager (RHPAM)][8] running on [Red Hat JBoss Enterprise Application Platform (JBoss EAP)][9] and using our *RDS instance* as the backend *MySQL* database.

## Let's dive in

### Create the VPC

---

If you're a cli user, you can use [scripts/aws_create_vpc.sh](scripts/aws_create_vpc.sh) and skip to the [Create the Security Groups section](#create-the-security-groups).

---

Create a *VPC* with the following characteristics:

```text
Name: Temenos RHPAM VPC
IPv4: 10.0.0.0/16
```

### Create the Subnets

Create **two** *Subnets* with the following characteristics:

A public designated subnet:

```text
VPC: <select the vpc you created>
Subnet Name: Temenos RHPAM Public Subnet
IPv4 CIDR block: 10.0.1.0/24
```

A private designated subnet:

```text
VPC: <select the vpc you created>
Subnet Name: Temenos RHPAM Private Subnet
IPv4 CIDR block: 10.0.0.0/24
```

Select the new **public** subnet and press *Actions* -> *Modify auto-assign IP settings*.</br>
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

Press *Actions* -> *Edit subnet associations* and select the public subnet you created.

### Create the Security Groups

---

If you're a cli user, you can use [scripts/aws_create_security_groups.sh](scripts/aws_create_security_groups.sh) and skip to the [Create or import a Key-Pair section](#create-or-import-a-key-pair).

---

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

### Create or import a Key-Pair

If you create a new *Key-Pair*,</br>
once created, you will be able to download the private key to your local station.

If you import an existing key,</br>
make sure to paste in the **public** key and not the private one.

If you're a cli user, you can use [scripts/create_import_keypair.sh](scripts/create_import_keypair.sh).

> If you create a new key, please consider 'chmod 400' the downloaded private key file.

---

Under Construction

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
