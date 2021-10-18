# Deploy an unmanaged MySQL EC2 Instance

[Get Back](../README.md).

## Create the initial EC2 Instance

---
If you are a *cli* user, you can use the following command and skip to the [Create an Elastic IP or an Elastic Load Balancer](#create-an-elastic-ip-or-an-elastic-load-balancer) section:

```shell
aws ec2 run-instances \
    --image-id ami-0b0af3577fe5e3532 \
    --instance-type <select an instance type> \
    --key-name <the name of the key-pair you created/imported> \
    --security-group-ids <the id of the security group you created for the backend> \
    --subnet-id <the subnet id of one of the created subnets> \
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
Subnet: <select one of the subnets you created>

```

### Add Storage

Add a New Volume and make sure the *Delete on Termination* is unchecked to make it a persistent volume.

> Note the device (i.e. `/dev/sdb`), we will use it later on for storing the database.

### Add Tags

```text
Name: Temenos RHPAM MySQL Unmanaged

```

### Configure Security Group

Select the *rhpam-mysql-back* Security Group you created.

## Create an Elastic IP or an Elastic Load Balancer

You will need static access to your instance,</br>
This means that you create either an *Elastic IP* or an *Elastic Load Balancer*, both options will provide a sort of static address for your instance.</br>

Whether you go for an IP or a load balancer, note the created IP/name, we'll use later on.

### Create an Elastic IP

---

If you are a *cli* user, you can use the following commands:

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

---

Allocate an Elastic IP address with the following characteristics:

```text
Network Border: <depends on your environment>
Tags: Name=Temenos MySQL Elastic IP
```

Press *Actions* and associate the elastic IP to your instance.

### Create an Elastic Load Balancer

---

If you are a *cli* user, you can use the following commands:

```shell
tg_arn=$(aws elbv2 create-target-group \
    --name rhpam-mysql-target \
    --protocol TCP \
    --port 3306 \
    --vpc-id <the vpc id> \
    --target-type instance \
    --tags "[{\"Key\": \"Name\", \"Value\": \"Temenos RHPAM MySQL Target Group\"}]" \
    --query TargetGroups[].TargetGroupArn --output text)

aws elbv2 register-targets \
    --target-group-arn $tg_arn \
    --targets Id=<your unmanged instance id>

read lb_arn lb_dns <<< $(aws elbv2 create-load-balancer \
    --name rhpam-mysql-load-balancer \
    --subnets <list of the **public** subnet id> \
    --type network \
    --tags "[{\"Key\": \"Name\", \"Value\": \"Temenos RHPAM MySQL Load Balancer\"}]"\
    --query "LoadBalancers[].[LoadBalancerArn,DNSName]" --output text)

aws elbv2 create-listener \
    --load-balancer-arn $lb_arn \
    --protocol TCP \
    --port 3306 \
    --default-actions Type=forward,TargetGroupArn=$tg_arn \
    --tags "[{\"Key\": \"Name\", \"Value\": \"Temenos RHPAM MySQL LB Listener\"}]" \
    > /dev/null

echo $lb_dns

unset tg_arn lb_arn lb_dns
```

---

Create a Target Group of type Instance with the following characteristics:

```text
Name: rhpam-mysql-target
Protocol: TCP
Port: 3306
VPC: <select the vpc you created>
Tags: Name=Temenos RHPAM MySQL Target Group
<select the instance you created>
```

Create a Load Balancer of type Network  with the following characteristics:

```text
Name: rhpam-mysql-load-balancer
VPC: <select the vpc you created>
Mapping: <select the **public** subnets in at least two zones>
Protocol: TCP
Port: 3306
Forward to: <your created target group>
Tags: Name=Temenos RHPAM MySQL Load Balancer

```

> Note the *DNS* name, we will use it later on.

## Install MySQL

Connect to the created instance using ssh:

```shell
ssh -i /path/to/private.pem ec2-user@mysql_elastic_ip
```

### Mount persistent storage

```shell
# identify device, i.e. */dev/sdb*
lsblk
# create ext4 filesystem
sudo mkfs -t ext4 <the device i.e. i.e. /dev/sdb>
# create folder for mounting
sudo mkdir /opt/mysql
# mount device to folder
sudo mount /dev/xvdb /opt/mysql
# verify mount
df -h /opt/mysql
# use sudo mode to set auto mount
sudo -i
echo '/dev/xvdb   /opt/mysql    ext4    defaults,nofail    0    0' >> /etc/fstab (add auto mount)
exit
# validate auto mount
sudo mount -a
```

### Install podman

```shell
sudo dnf update -y
sudo dnf install podman policycoreutils-python-utils -y
```

### Set SELinux context

```shell
sudo semanage fcontext -a -t container_file_t '/opt/mysql(/.*)?'
sudo restorecon -Rv /opt/mysql
```

### Run MySQL container

**Note the password.**

```shell
sudo podman run -d \
    --name mysql \
    -p 3306:3306 \
    -v /opt/mysql:/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=redhat \
    -e MYSQL_DATABASE=jbpm \
    docker.io/library/mysql:8.0.26
```

### Set the container to run on startup

```shell
sudo -i
podman generate systemd --new --name mysql > /etc/systemd/system/mysql-container.service
exit
sudo systemctl enable mysql-container
sudo systemctl start mysql-container
```

### Optionally create an AMI

It's recommended to create an *Amazon Machine Image (AMI)* at this point to avoid re-running the
above instructions, and allow better scalability.

<!-- links -->
[0]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
