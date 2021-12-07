## Deployment of infrastructrure components
Steps accomplished from the reference page [Deploy RHPAM 7.11.1 AWS with a PostgreSQL backend][reference-procedure]
* Create or import a Key-Pair: `rhpam.pem`
* ~~Create the Elastic IPs~~
* ~~Create the Policy~~
* ~~Create the Role~~
* Create the VPC: `RHPAM VPC`
* Create the Subnets: only `Public us-east-1a Subnet` and `Public us-east-1b Subnet`
* ~~Create the NAT Gateway~~
* Create the Internet Gateway
* Create the Route Tables
* Create the Security Groups: only one with all needed Inbound rules and one Outbound rule for all traffic, ports, protocols and destinations
* ~~Create the Subnet Group~~: this ws delegated to the `Create Database` wizard, instead
* Create the PostgreSQL DB Managed RDS Instance
* Create the base EC2 Instance and AMI: actually skipped the creation of the base image
  * JDK + pql, no aws CLI
* Create the RHSSO Instance, AMI, ELB, and ASG
  * No AMI, ELB, ASG
  * No PostgresQL driver
  * Create DB schema
  * No ALB, ASG
  * Also anticipated the initialization of the `jbpm` schema from instructions in `Create the KIE Server Instance, AMI, and ASG`
  
## Software inventory
Place the required sofware artifacts under the `resources` folder, in the expected sub-folders
### jboss-eap-7.3.6 folder
[jboss-eap-7.3.0-installer.jar][jboss-eap-installer]
[jboss-eap-7.3.9-patch.zip][jboss-eap-patch]
[rh-sso-7.4.9-eap7-adapter.zip][sso-eap7-adapter]
### rhpam folder
[rhpam-installer-7.11.1.jar][rhpam-installer]

## SSO Configuration
* Controller user: `controller/controller123#` (used in KIE Server configuration)
* KIE Server user: `kieserver/redhat123#` (used in Busioness Central configuration)
* Business Central user: `rhpam/admin`

## Install KIE Server
Update the environment properties in [kie-server.sh](./kie-server.sh) and the runtime properties in [runtime.properties](./resources/kie-server/runtime.properties) 
and run it:
```shell
./kie-server.sh
```

## Install Business Central Instance
fill in the automation properties with all necessary values in  [business-central.properties](./business-central.properties) 
and run the the following bash script to initiate business central automation::
```shell
./business-central.sh
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

<!-- links -->
[reference-procedure]: https://github.com/RHEcosystemAppEng/rhpam-deployment/tree/main/eap/rhpam-on-aws-with-managed-postgresql
[jboss-eap-installer]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=appplatform&version=7.3
[jboss-eap-patch]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?product=appplatform&downloadType=patches&version=7.3
[sso-eap7-adapter]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?product=core.service.rhsso&downloadType=patches&version=7.4
[rhpam-installer]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=rhpam&version=7.11.1
