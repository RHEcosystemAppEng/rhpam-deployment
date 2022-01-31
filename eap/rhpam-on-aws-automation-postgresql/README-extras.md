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
