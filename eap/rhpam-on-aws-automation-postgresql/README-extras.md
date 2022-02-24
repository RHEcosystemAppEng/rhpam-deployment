## Configuring Keycloak
Follow instructions at [README.md](../../integrations/keycloak/README.md)

### Mounting EFS filesystem (optional)
In case we need to mount an EFS filesystem, the [efs.sh](./efs/efs.sh) script is available to initialize the mount point
on the target VM.

See related [efs.properties](./efs/efs.properties) configuration properties to define the mounted path.

## Deployment Notes
### Unique server ID
This `bash` function returns the local host name of the current AWS EC2 VM, purged of the suffix `.ec2.internal`:
```shell
function get_hostname() {
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") &&
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-hostname | cut -d'.' -f1
}
```
E.g., it returns something like `ip-10-0-1-211` which is unique within the local subnet.

### Static access to Business Central (BC)
BC uses an Auto Scale Group with capacity/min/max of 1 for automatic recovery. The ASG can be standalone or in conjunction with a Load Balancer.
When using a LB, access from other systems (controller address from KS, client urls/uris in Keycloak) will be through using the LB DNS.
Without an LB or, if KS needs to access BC directly NOT through the LB, BC needs to use a static IP.
Runbook steps taken from [rhpam-on-aws-with-managed-postgresql runbook](../rhpam-on-aws-with-managed-postgresql/README.md) are marked with an __

#### With Load Balancer
- Create the Target Groups
- Create the Load Balancer  
  receives a DNS with the following syntax: **name-id**.elb.**region**.amazonaws.com
- Create the Launch Configuration
- Create the Auto Scaling Group
- Update BC host in urls/uris in Keycloak -> client -> business-central
- Update Bc host in KS runtime.properties on Ks instance -> restart ks.service

#### Without Load Balancer
- Create Elastic IP with TAG: `key:app, value=bc-eip`
- Run `./installer/eip_attach/installer.sh`
- Update BC host in urls/uris in Keycloak -> client -> business-central
- Update Bc host in KS runtime.properties on Ks instance -> restart ks.service

### Good practices when testing things out on AWS:
1. Stop resources (VMs, Databases, etc) at end of working day
2. Delete obsolete AMIs: deregister AMI (note the AMI id) AND delete its snapshot using the AMI ID to find the correct one
3. Release any not needed EIPs. An EIP is only free of charge if a couple of constraints are met: it must be associated with a RUNNING EC2 instance which has only one EIP attached and it also must be associated with an attached network interface [source](https://aws.amazon.com/premiumsupport/knowledge-center/elastic-ip-charges/)
4. VMs used by an ASG can be stopped BUT the ASG might/will spin up another instance instead => set capacity/min/max to 0

## Production pipeline evaluation

Before building immutable image: 
```shell
/system-property=org.kie.server.mgmt.api.disabled:add(value=true)
```

### Preliminary step: create `ks-7.9.1-unmanaged-server` AMI
Manual procedure:
* Configure VM, DB and Keycloak settings in [installer.properties](./installer.properties) and [runtime.properties](./runtime/kie-server/runtime.properties)
then run `installer.sh`
* Validate against Postman:
  * [ ] Get health status using `GET http://{{kieserver-url}}/services/rest/server/healthcheck`
  * [ ] Get readiness status using `GET http://{{kieserver-url}}/services/rest/server/readycheck`
  * [ ] Get server info using `GET http://{{kieserver-url}}/services/rest/server`
  * [ ] Get list of available containers using `GET http://{{kieserver-url}}/services/rest/server/containers`
* Create image from running server: `ks-7.9.1-unmanaged-server`
  * All default settings
  * No AWS command, this image remains to be used for next deployments

### Step 1: Create the template VM from `ks-7.9.1-unmanaged-server` AMI
First fetch the image (after state=available)
```shell
UNMANAGED_SERVER_AMI_ID=$(aws ec2 describe-images --owners self --query 'Images[*].[ImageId]' --output text --filters "Name=name,Values=ks-7.9.1-unmanaged-server")
```
Response example:
```shell
ami-00398e6ad98bb945d   ks-7.9.1-unmanaged-server
```

Then create the EC2 from this image:
* Requires: 
  * security group id
  * key pair name
  * subnet id
```shell
aws ec2 run-instances --image-id "$UNMANAGED_SERVER_AMI_ID" --count 1 \
--instance-type t2.medium --key-name rhpam-temenos --security-group-ids sg-043cac2b1fed4a2f5 --subnet-id subnet-0cd999926c8befd4f \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=template-ks-7.9.1},{Key=type,Value=template-server}]' --no-dry-run
```

**Note**: in case of EFS mounted filesystem, we need to update the service configuration as follows:
```shell
Wants=network-online.target ${EFS_MOUNT_UNIT}
After=network-online.target ${EFS_MOUNT_UNIT}
```

### Step 2: Wait until Kie Server is ready
* Get public IP address:
```shell
UNMANAGED_SERVER_ID=$(aws ec2 describe-tags --filters 'Name=resource-type,Values=instance' 'Name=tag:type,Values=template-server'  | jq -r '.Tags[0].ResourceId' )
UNMANAGED_SERVER_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$UNMANAGED_SERVER_ID" | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
```
* Invoke REST and wait until it returns HTTP status 200:
```shell
until $(curl --output /dev/null --silent --head --fail http://${UNMANAGED_SERVER_PUBLIC_IP}:8080/kie-server/services/rest/server/readycheck); do
      printf '.'
      sleep 5
done
```

### Step 3: Deploy new artifacts
Input parameters:
* containerId
* groupId
* artifactId
* version
* username
* password
```shell
DEPLOYMENT_RESULT=$(curl -X PUT "http://${UNMANAGED_SERVER_PUBLIC_IP}:8080/kie-server/services/rest/server/containers/${containerId}" \
--user "$username:$password" \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--data-raw '{
    "container-id": "'"${containerId}"'",
    "release-id": {
        "group-id": "'"${groupId}"'",
        "artifact-id": "'"${artifactId}"'",
        "version": "'"${version}"'"
    }
}')
```

Validation: `echo "$DEPLOYMENT_RESULT" | jq -r '.type'` must be `SUCCESS`

### Step 4: Configure the immutable server
```shell
ssh -i rhpam.pem ec2-user@$UNMANAGED_SERVER_PUBLIC_IP \
"sudo /opt/rhpam-7.9.1/bin/jboss-cli.sh -c --command='/system-property=org.kie.server.mgmt.api.disabled:add(value=true)'"
```

### Step 5: Create new AMI for immutable server
```shell
SERVER_NAME="ks-7.9.1-immutable-${containerId}-v${version}"
SHORT_SERVER_NAME="${containerId}-v${version//\./-}"
aws ec2 create-image --instance-id "${UNMANAGED_SERVER_ID}" --name "${SERVER_NAME}"
```

### Step 6: Terminate the template VM
```shell
aws ec2 terminate-instances --instance-ids "${UNMANAGED_SERVER_ID}"
```

### Step 7: Create Launch Configuration
```shell
IMMUTABLE_SERVER_AMI_STATE=$(aws ec2 describe-images --owners self --filters "Name=name,Values=${SERVER_NAME}" | jq -r '.Images[0'].State)
until [[ $IMMUTABLE_SERVER_AMI_STATE == "available" ]]
do
  echo "AMI state is ${IMMUTABLE_SERVER_AMI_STATE}"
  sleep 5
  IMMUTABLE_SERVER_AMI_STATE=$(aws ec2 describe-images --owners self --filters "Name=name,Values=${SERVER_NAME}" | jq -r '.Images[0'].State)
done

IMMUTABLE_SERVER_AMI_ID=$(aws ec2 describe-images --owners self --filters "Name=name,Values=${SERVER_NAME}" | jq -r '.Images[0'].ImageId)
aws autoscaling create-launch-configuration --launch-configuration-name "${SERVER_NAME}" \
--image-id "${IMMUTABLE_SERVER_AMI_ID}" \
--instance-type t2.medium \
--associate-public-ip-address \
--security-groups sg-043cac2b1fed4a2f5 \
--key-name rhpam-temenos
```
### Step 8: Create Auto Scaling Group
Input:
* subnet IDs
* desired, min and max capacity
```shell
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name "${SERVER_NAME}"  \
    --launch-configuration-name "${SERVER_NAME}" \
    --min-size 1 \
    --max-size 5 \
    --desired-capacity 2 \
    --vpc-zone-identifier "subnet-0a30348124fec0160,subnet-0cd999926c8befd4f" \
    --tags "ResourceId=${SERVER_NAME},ResourceType=auto-scaling-group,Key=app,Value=RHPAM-KS,PropagateAtLaunch=true" \
    "ResourceId=${SERVER_NAME},ResourceType=auto-scaling-group,Key=container,Value=${containerId}-v${version},PropagateAtLaunch=true"
```

### Step 9: Wait until all new servers are ready
**Note**: only 1 of the launched VMs can have a public IP, this is not an issue with Jenkins pipeline as it works with private IPs,
we're applying a check here to skip those with null public IP

```shell
IMMUTABLE_SERVER_IPS=($(aws ec2 describe-instances --filters "Name=instance-state-name,Values=pending,running" "Name=tag:container,Values=${containerId}-v${version}"  | jq -r '.Reservations[] | .Instances[0].PublicIpAddress'))

for ip in ${IMMUTABLE_SERVER_IPS}; do
  echo "Checking $ip"
  if [ "$ip" = "null" ]; then
    echo "Skipping"
  else
    echo "Waiting until $ip is ready"
    until $(curl --output /dev/null --silent --head --fail http://${ip}:8080/kie-server/services/rest/server/readycheck); do
          printf '.'
          sleep 5
    done
  fi
done
```

### Step 10 - Create new Target Group
Input parameters:
* vpc ID
* subnet IDs

```shell
aws elbv2 create-target-group \
    --name "${SHORT_SERVER_NAME}" \
    --protocol HTTP \
    --port 8080 \
    --target-type instance \
    --vpc-id vpc-0426a430cbd4b72a5
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names "${SHORT_SERVER_NAME}" | jq -r '.TargetGroups[0].TargetGroupArn')

# IF NOT EXISTS OTHERWISE REUSE IT
aws elbv2 create-load-balancer \
  --name "${SHORT_SERVER_NAME}" \
  --type application \
  --scheme internet-facing \
  --subnets subnet-0a30348124fec0160 subnet-0cd999926c8befd4f \
  --security-groups sg-043cac2b1fed4a2f5
LOAD_BALANCER_ARN=$(aws elbv2 describe-load-balancers --names "${SHORT_SERVER_NAME}" | jq -r '.LoadBalancers[0].LoadBalancerArn')

aws autoscaling attach-load-balancer-target-groups \
  --auto-scaling-group-name "${SERVER_NAME}" \
  --target-group-arns "${TARGET_GROUP_ARN}"

aws elbv2 create-listener \
  --load-balancer-arn "${LOAD_BALANCER_ARN}" \
  --protocol HTTP \
  --port 80 \
  --default-actions "Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}"
```
