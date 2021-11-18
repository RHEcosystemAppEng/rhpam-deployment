# RHPAM deployment runbook
Purpose of this project is to define a mostly automated procedure to create a scalable RHPAM setup on the Azure platform.

Multiple options are supported:
* Design Time environment:
  * RHPAM KIE Server and Business Central
  * Managed KIE Server
  * No VM Scale Set is needed
  * This environment is used to develop projects and deploy them on the KIE Server
* Runtime environment:
  * Unmanaged RHPAM KIE Server
  * With VM Scale Set and Azure Load Balancer
  * This environment is used to run a scalable architecture of KIE Server instances managing the projects defined at
  design time (immutable server pattern)

Target version is `RHPAM 7.9.0`

## Prerequisites
* Azure account
* Deploy 1 (Runtime environment) or 2 (Design Time environment) VM with base RHEL 8.2 image
  * TCP SSH port must be accessible from any IP
  * TCP 8080 port must be accessible from any IP
  * `azureuser` managemebt user is requested
  * public IP is requested
  * VMs must be in the same subnet
* An external Maven repository (e.g. [Repsy.io][0])
* An external MySql DB, accessible by the KIE Server VM and initialized with the `jbpm` DB schema
  * The [ks/standalone-full.xml](./ks/standalone-full.xml) must be updated with specific configuration of the JDBC 
  data source (look for `java:/jbpmDS` in the xml file)
* Populate the `resources` folder with all the required binaries from the [Software Downloads][1] page:
    * `jboss-eap-7.3.0-installer.jar`
    * `rhpam-installer-7.9.0.zip`

## Configure the deployment properties
Update the template [deployment.properties](./deployment.properties) with actual values for:
* MAVEN_REPO_USERNAME: username to access the Maven repository
* MAVEN_REPO_PASSWORD: password to access the Maven repository
* MAVEN_REPO_URL: URL of the Maven repository
* BUSINESS_CENTRAL_HOSTNAME: public IP or hostname of the Business Central VM [only for design time deployment]
* EAP_HOME: root installation folder of RHPAM on the VM
* KIE_SERVER_IP: public IP of the KIE Server VM
* BUSINESS_CENTRAL_IP: public IP of the Business Central VM [only for design time deployment]
* SSH_PEM_FILE: private key to access the Azure cloud via SSH 

## Deploy and configure the KIE Server
The following command will deploy on the KIE Server VM all the required software and then install and configure both 
`EAP JBoss 7.3` and `RHPAM 7.9.0`:
```shell
./kie-server.sh
```

**Notes**: by default, the above command will deploy a managed server. If you want to just deploy an unmanaged (but with no
default containers deployed) you have to comment or delete the following properties in [ks/standalone-full.xml](./ks/standalone-full.xml)
* org.kie.server.controller
* org.kie.server.controller.user
* org.kie.server.controller.pwd
* org.kie.server.location

The deployment also defines a `ks.service` service which is automatically started and enabled at next server restarts. 

The JBoss EAP is configured with a default administrator user as `admin/password`.
The default installation also pre-loads an administrative user `rhpamAdmin/redhat123#` and a user with `kie-server` role as
`kieserver/kieserver1!`. Details in [ks/application-users.properties](./ks/application-users.properties) and 
[ks/application-roles.properties](./ks/application-roles.properties)

To troubleshoot the runtime server, SSH into the VM and run the following commands:
```shell
ssh -i <SSH_PEM_FILE> azureuser@KIE_SERVER_IP sudo journalctl -u ks.service -f
```
## Deploy and configure the Business Central
[Only for Design Time environment]
The following command will deploy on the Business Central VM all the required software and then install and configure both
`EAP JBoss 7.3` and `RHPAM 7.9.0`:
```shell
./business-central.sh
```

To properly deploy projects in the configured Maven repository, add this section at the end of the `pom.xml` for any
new project:
`<distributionManagement>
    <repository>
        <id>rhpam</id>
        <url><MAVEN_REPO_URL></url>
    </repository>
</distributionManagement>
`
The deployment also defines a `bc.service` service which is automatically started and enabled at next server restarts.

The JBoss EAP is configured with a default administrator user as `admin/password`.
The default installation also pre-loads an administrative user `rhpamAdmin/redhat123#` and a user with `kie-server` role as
`controllerUser/controllerUser1234`. Details in [bc/application-users.properties](./bc/application-users.properties) and
[bc/application-roles.properties](./bc/application-roles.properties)

To troubleshoot the runtime server, SSH into the VM and run the following commands:
```shell
ssh -i <SSH_PEM_FILE> azureuser@BUSINESS_CENTRAL_IP sudo journalctl -u bc.service -f
```
## Setup validation
If you deployed the Design time environment, open `http://BUSINESS_CENTRAL_HOSTNAME:8080/business-central` and login 
as `rhpamAdmin/redhat123#` to start working on your projects. Otherwise, access the `Swagger` page of the KIE Server at
`http://KIE_SERVER_IP:8080/kie-server/docs` to start working with the public REST APIs.

## Create KIE Server image and scale set
See instructions at [ks-azure-setup.md](./ks-azure-setup.md)

## Load Balancer Issues 
###  org.hibernate.StaleObjectStateException
This issue is tracked by [Task instance marked as Completed despite OptimisticLockException][2]
* Outstanding in 7.9.0
* Fixed in 7.10.1.GA, 7.11.0.GA
**Note**: the fix introduced the configurable property `org.kie.optlock.retries` to define the number of commit attempts 
(default is 3)

#### Issue
Failed commits of database transaction. 
The symptom is the following error message in the `server.log`, which indicates a failed commit in the database: 
```text
2021-11-17 07:49:00,479 WARN  [org.drools.persistence.PersistableRunner] (default task-1) Could not commit session: java.lang.RuntimeException: Unable to commit transaction
...
at deployment.kie-server.war//org.jbpm.kie.services.impl.ProcessServiceImpl.startProcess(ProcessServiceImpl.java:151)
at deployment.kie-server.war//org.kie.server.services.jbpm.ProcessServiceBase.startProcess(ProcessServiceBase.java:100)
at deployment.kie-server.war//org.kie.server.remote.rest.jbpm.ProcessResource.startProcess(ProcessResource.java:180)
...
Caused by: javax.persistence.OptimisticLockException: Row was updated or deleted by another transaction (or unsaved-value mapping was incorrect) : [org.drools.persistence.info.SessionInfo#6]
```
#### Root Cause
Multiple KIE Server instances executing requests for the same deployment container are trying to update the same record 
in the `sessioninfo` table, the first commit wins, the others throw an error.
According to above [Jira issue][2], the expectation is that [OptimisticLockRetryInterceptor][3] would retry
for the configured number of attempts and rollback the entire transaction only when all the attempts fail.
#### Diagnostic Steps
To add more details in the log, from `jboss-cli` update the following logger level:
```
/subsystem=logging/logger=org.drools.persistence.jpa:add(level=TRACE)
```
Then you can see more messages at TRACE level in `server.log`, like:
```text
2021-11-17 08:12:52,334 TRACE [org.drools.persistence.jpa.OptimisticLockRetryInterceptor] (default task-1) Command failed due to optimistic locking java.lang.RuntimeException: Unable to commit transaction waiting 50 millis before retry
```

If you look at the `sessioninfo` table in the DB, the version number is reflected by the `OPTLOCK` columns, as defined
in the [SessionInfo][4] Entity
#### Impacts
This issue only impacts the content of the `SessionInfo` Entity, so it has no impacts on the application data.

### Errors due to managed KIE Server
If you are running a managed KIE Server and you don't have a Business Central running, you may hit one of the following
errors while executing the server's APIs:
```text
Unexpected error during processing: Container 'test_1.0.1-SNAPSHOT' is not instantiated or cannot find container for alias 'test_1.0.1-SNAPSHOT'
...
parse error: Invalid string: control characters from U+0000 through U+001F must be escaped at line 2, column 1
...
User '[UserImpl:'rhpamAdmin']' was unable to execute operation 'Complete' on task id 1214 due to a no 'current status' match
```

You have to adjust the server configuration as suggested by [How to convert a managed kie-server to unmanaged using RHPAM?][5]

## Open Items
* Configure the Azure Load Balancer to monitor a well-defined REST endpoint (e.g. `kie-server/services/rest/server/containers`)
to evaluate the health status of each server
  * Sometimes server receive requests before being ready to manage it, and reply with error
* In the Design time environment, if we launch multiple servers they will all have the same hostname, so the Business Central
would only show one instance on the `Execution servers` page

<!-- links -->
[0]: https://repsy.io/
[1]: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=rhpam&version=7.09.0
[2]: https://issues.redhat.com/browse/RHPAM-3487
[3]: https://github.com/kiegroup/drools/blob/5824a9bdf90be6bab69cb4477e60888ad3a99222/drools-persistence/drools-persistence-jpa/src/main/java/org/drools/persistence/jpa/OptimisticLockRetryInterceptor.java#L102
[4]: https://github.com/kiegroup/drools/blob/acaf6a03837ac814265c3846f274d20b3338bc12/drools-persistence/drools-persistence-jpa/src/main/java/org/drools/persistence/info/SessionInfo.java
[5]: https://access.redhat.com/solutions/6262221