## Deployment of infrastructure components 
This procedure is defined to provide an automated installation and configuration of RHPAM services on the AWS cloud.
Installed components include:
* RHPAM Business Central (v. 7.9.1)
* RHPAM Kie Server (v. 7.9.1)
* Configuration of Keycloak (v. 12.0.2)
* Configuration of PostgresQL

## Software inventory
Place the required software artifacts under the `installer` folder, in the expected sub-folders
### jboss-eap folder
[jboss-eap-7.3.0-installer.jar][jboss-eap-installer]
[jboss-eap-7.3.6-patch.zip][jboss-eap-patch]
[keycloak-oidc-wildfly-adapter-12.0.4.zip][keycloak-adapter]
### rhpam folder
[rhpam-installer-7.9.1.jar][rhpam-installer]
### database folder
[rhpam-7.9.1-add-ons.zip][rhpam-add-ons]

## Configuring dependant components
### Configuring Keycloak
Install following instructions in [keycloak installer manual](./keycloak/Readme.md)

### Configuring PostgresQL
The database is created and initialized during the creation of the KIE Server, in case it is not already there, using
the connection properties defined in [runtime.properties](./runtime/kie-server/runtime.properties)

### Mounting EFS filesystem
In case we need to mount an EFS filesystem, the [efs.sh](./efs/efs.sh) script is available to initialize the mount point
on the target VM. See related [efs.properties](./efs/efs.properties) configuration properties to define the mounted path.
**Note**: in case of mounted EFS filesystem, we will use this path to store `runtime.properties` and, for the `Business Central` 
service, also to host the local Git repository.

## Install and configure RHPAM services
These steps are performed with the [installer.sh](./installer.sh) script that is configured with the following properties
in [installer.properties](./installer.properties): 
*`RHPAM_SERVER_IP`: the public IP of the VM to configure
* `SSH_PEM_FILE`: the SSH key file
* `SSH_USER_ID`: the SSH user
* `RHPAM_SERVER`: one of: `business-central` or `kie-server`
* `KIE_SERVER_TYPE`: only for `RHPAM_SERVER=kie-server`, one of: `unmanaged` or `managed`
* `EAP_HOME`: the root folder of RHPAM installation
* `RHPAM_HOME`: The RHPAM home folder (maven settings file, kie server config file)
* `RHPAM_PROPS_DIR`: where rhpam properties are stored (runtime.properties). In case of EFS mounted filesystem, it has to 
match the mounted path
* `GIT_HOME`: only for `RHPAM_SERVER=business-central`, the folder where git repository is located (as `.niogit/`).
In case of EFS mounted filesystem, it has to match the mounted path
* `DRY_RUN_ONLY`: set to "yes" to generate only the list of commands in the `installer.log` file

## Install KIE Server
Update the environment properties in [installer.properties](./installer.properties), in particular:
* `RHPAM_SERVER`: must be `kie-server`
* `KIE_SERVER_TYPE`: either `managed` or `unmanaged`

Also update all the runtime properties in [runtime.properties](./runtime/kie-server/runtime.properties) to connect to the
actual Keycloak and PostgresQL instances, then run it as:
```shell
./installer.sh
```

## Install Business Central
Update the environment properties in [installer.properties](./installer.properties), in particular:
* `RHPAM_SERVER`: must be `business-central`

Also update all the runtime properties in [runtime.properties](./runtime/business-central/runtime.properties) to connect to the
actual Keycloak instance, then run it as:
```shell
./installer.sh
```

## Open points
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
- __**Create the Target Groups**  
- __**Create the Load Balancer**  
receives a DNS with the following syntax: **name-id**.elb.**region**.amazonaws.com  
- __**Create the Launch Configuration**  
- __**Create the Auto Scaling Group**  
- Update BC host in urls/uris in Keycloak -> client -> business-central
- Update Bc host in KS runtime.properties on Ks instance -> restart ks.service

#### Without Load Balancer
- Create Elastic IP with TAG: `key:app, value=bc-eip`
- Run `./installer/eip_attach/installer.sh` 
- Update BC host in urls/uris in Keycloak -> client -> business-central
- Update Bc host in KS runtime.properties on Ks instance -> restart ks.service

### Good practices when testing things out on AWS:
1. stop resources (VMs, Databases, etc) at end of working day
2. delete obsolete AMIs: deregister AMI (note the AMI id) AND delete its snapshot using the AMI ID to find the correct one
3. EIPs are free of charge if a couple of constraints are met, one of them being that the EIP is attached to a RUNNING instance
   -> if instance is stopped, an associated EIP to that instance again incurs costs
4. VMs used by an ASG can be stopped BUT the ASG might/will spin up another instance instead => set capacity/min/max to 0

<!-- links -->
[reference-procedure]: https://github.com/RHEcosystemAppEng/rhpam-deployment/tree/main/eap/rhpam-on-aws-with-managed-postgresql
[jboss-eap-installer]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=appplatform&version=7.3
[jboss-eap-patch]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?product=appplatform&downloadType=patches&version=7.3
[keycloak-adapter]: https://www.keycloak.org/archive/downloads-12.0.4.html
[rhpam-installer]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=rhpam&version=7.09.1
[rhpam-add-ons]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=rhpam&version=7.09.1
