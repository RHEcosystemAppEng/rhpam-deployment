## Deployment of infrastructrure components
Steps accomplished from the reference page [Deploy RHPAM 7.11.1 AWS with a PostgreSQL backend][0]
* Create or import a Key-Pair: `temenos-rhpam-aws`
* ~~Create the Elastic IPs~~
* ~~Create the Policy~~
* ~~Create the Role~~
* Create the VPC: `Temenos RHPAM VPC`
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


## Open points
### Evaluate server ID
This `bash` function returns the local host name of the current AWS EC2 VM, purged of the suffix `.ec2.internal`:
```shell
function get_local_hostname() {
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") && 
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-hostname | cut -d '.' -f 1
}
```
E.g., it returns something like `ip-10-0-1-211` which is unique within the local subnet.

<!-- links -->
[0]: https://github.com/RHEcosystemAppEng/temenos-infinity-cib/tree/main/eap/rhpam-on-aws-with-managed-postgresql


