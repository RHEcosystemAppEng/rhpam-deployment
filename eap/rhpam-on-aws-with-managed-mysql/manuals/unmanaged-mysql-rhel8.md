# Deploy an unmanaged MySQL EC2 Instance

[Get Back](../README.md).

## Create the initial EC2 Instance

---
If your a *cli* user, you can use the following command and skip to the [Create an Elastic IP or an Elastic Load Balancer](#create-an-elastic-ip-or-an-elastic-load-balancer) section:

```shell
aws ec2 run-instances \
    --image-id ami-0b0af3577fe5e3532 \
    --instance-type <select an instance type> \
    --key-name <the name of the key-pair you created/imported> \
    --security-group-ids <the id of the security group you created for the backend> \
    --subnet-id <the subnet id of one of the created **private** subnets> \
    --tag-specifications "ResourceType=instance, Tags=[{Key=Name, Value=Temenos RHPAM MySQL Unmanaged}]" \
    --block-device-mappings "[{\"DeviceName\": \"/dev/sdb\", \"Ebs\": {\"DeleteOnTermination\": false, \"VolumeSize\": 10 }}]" \
    --no-associate-public-ip-address 
```

---

### Choose AMI

Create an *EC2 Instance* from the base **AMI for Red Hat Enterprise Linux 8**.</br>
Use the unsubscribed *Red Hat Enterprise Linux 8* bare installation from the *EC2 AMI* list in the wizard.</br>
For searching refference, or if you're using the *cli*, the *AMI* id for a 64x86 *AMI* is `ami-0b0af3577fe5e3532`.

### Choose Instance Type

Note that you will need to select an [EC2 Instance Type][0] for your instance.

### Configure Instance

```text
Network: <select the vpc you created>
Subnet: <select on of the **private** subnets you created>

```

> Having subnets in multiple availibilty zones is not mandatory when opting for the unmanaged db instance.

### Add Storage

Add a New Volume and make sure the *Delete on Termination* is unchecked to make it a persistant volume.

> Note the device (i.e. `/dev/sdb`), we will use it later on for storing of the database.

### Add Tags

```text
Name: Temenos RHPAM MySQL Unmanaged

```

### Configure Security Group

Select the *rhpam-mysql-back* Security Group you created.

## Create an Elastic IP or an Elastic Load Balancer

You will need static access to your instance,</br>
This means that you create either an *Elastic IP* or an *Elastic Load Balancer*, both options will provide a sort of static address for your instance.</br>
It's no mandatory, you can stick to the dynamic public ip assinged to your instance.

Weather you go for an ip or a load balancer, note the created ip/name, we'll use later on.

### Create an Elastic IP

If your a *cli* user, you can use the following commands:

```shell
allocation_id=$(aws ec2 allocate-address \
  --network-border-group <select you border group, i.e. us-east-1> \
  --tag-specifications "ResourceType=elastic-ip, Tags=[{Key=Name, Value=Temenos RHPAM MySQL Elastic IP}]" \
  --query AllocationId --output text)

aws ec2 associate-address \
    --instance-id <the id of your instance> \
    --allocation-id $allocation_id

unset allocation_id
```

Allocate an Elastic IP address with the following characteristics:

```text
Network Border: <depends on your environment>
Tags: Name=Temenos MySQL Elastic IP
```

Press *Actions* and associate the elastic ip to your instance.

### Create an Elastic Load Balancer

---
Under Construction

---

## Install MySQL

---
Under Construction

---

<!-- links -->
[0]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
