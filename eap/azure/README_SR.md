# Smart Router deployment runbook
Purpose of this project is to define a mostly automated procedure to create KIE servers accessed via Smart Router on the Azure platform.

Options supported are:
* Runtime environment:
  * Unmanaged, immutable RHPAM KIE Server
  * Unmanaged RHPAM Smart Router
  * This environment is used to manually run KIE Server instances (todo on request: scalable via VMSS) managing the projects defined at
  design time (immutable server pattern)

Target version is `RHPAM 7.9.0`

## Prerequisites
* Azure account
* Deploy 2 VM with base RHEL 8.2 image
  * TCP SSH port must be accessible from any IP
  * TCP 8080 port must be accessible from any IP (kie server)
  * TCP 9000 port must be accessible from any IP (smart router)
  * `azureuser` management user is requested
  * public IP is requested
  * VMs must be in the same subnet
* An external Maven repository (e.g. [Repsy.io][0])
* An external MySql DB, accessible by the KIE Server VM and initialized with the `jbpm` DB schema
  * The [ks/standalone-full.xml](./ks/standalone-full.xml) must be updated with specific configuration of the JDBC 
  data source (look for `java:/jbpmDS` in the xml file)
* Populate the `resources/ks` folder with all the required binaries from the [Software Downloads][1] page:
    * `jboss-eap-7.3.0-installer.jar`
    * `rhpam-installer-7.9.0.jar`
* Populate the `resources/sr` folder with:
  * `rhpam-7.9.0-smart-router.jar` from  [Software Downloads][1] page - `Red Hat Process Automation Manager 7.9.0 Add-Ons` archive

## Configure the deployment properties for the kie server
see [kie server deployment properties](README.md)

## Deploy and configure the Smart Router
The following command will deploy on the Smart Router VM all the required software:
```shell
./smart-router.sh
```
The deployment also defines a `sr.service` service which is automatically started and enabled at next server restarts.

To troubleshoot the runtime server, SSH into the VM and run the following commands:
```shell
ssh -i <SSH_PEM_FILE> azureuser@SMART_ROUTER_SERVER_IP sudo journalctl -u sr.service -f
```

## Deploy and configure the Kie Server
The following command will deploy on the KIE Server VM all the required software and then install and configure both
`EAP JBoss 7.3` and `RHPAM 7.9.0`:
```shell
./kie-server.sh UNMANAGED_WITH_SMARTROUTER
```
**Notes**: 
* the UNMANAGED_WITH_SMARTROUTER parameter will install a kie server without controller properties
Apart from that the installation is the same described here [Deploy and configure the KIE Server](README.md)
* to identify a kie server on the router uniquely, the kie server url is built using each servers
private ip and not it's `hostname`. The KIE_SERVER_ID will be the same for all created servers, since it
is used for the configuration file name which must be saved inside the kie server image to create an immutable server.

## Setup validation
```
Open `http://SMART_ROUTER_HOST:SMART_ROUTER_PORT/mgmt/list`
Response should show containerInfo, containers and servers not empty, see example:
{
  "containerInfo": [{
    "alias": "simplebc",
    "containerId": "com.myspace:simplebc:1.0.1-SNAPSHOT",
    "releaseId": "com.myspace:simplebc:1.0.1-SNAPSHOT"
  }],
  "containers": [
    {"simplebc": ["http://<KIE_SERVER_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server"]},
    {"com.myspace:simplebc:1.0.1-SNAPSHOT": ["http://<KIE_SERVER_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server"]}
  ],
  "servers": [{"default-kieserver": ["http://<KIE_SERVER_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server"]}]
}
```
With more than one kie server registered to the smart router, we will see them either as separate entries under the `servers` entry
if the kie server id is different (default-kieserver, default-kieserver2) or as one entry with several urls,
if the kie server id is the same. Both options forward requests evenly between the registered servers.
```
"servers": [
    {"default-kieserver2": ["http://<KIE_SERVER2_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server"]},
    {"default-kieserver": ["http://<KIE_SERVER1_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server"]}
  ]
```
or
```
"servers": [
    {"default-kieserver": [
    "http://<KIE_SERVER2_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server",
    "http://<KIE_SERVER1_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server"
    ]}
  ]
```

## Troubleshooting
Empty response for query `http://SMART_ROUTER_HOST:SMART_ROUTER_PORT/mgmt/list`
```
{
"containerInfo": [],
"containers": [],
"servers": []
}
```
Kie servers do register automatically when containers are started or stopped. Manually refresh the container to force a registration:
```
curl -X POST "http://<KIE_SERVER_IP>:<KIE_SERVER_PORT>/kie-server/services/rest/server/config" \ 
-H "accept: application/json" \ 
-H "content-type: application/json" \ 
-d "{ \"commands\": [ { \"dispose-container\": { \"container-id\": \"com.myspace:simplebc:1.0.1-SNAPSHOT\" } }, { \"create-container\": { \"container\": { \"status\": \"STARTED\", \"container-id\": \"com.myspace:simplebc:1.0.1-SNAPSHOT\", \"release-id\": { \"version\": \"1.0.1-SNAPSHOT\", \"group-id\": \"com.myspace\", \"artifact-id\": \"simplebc\" } } } } ]}"
```
Note: just activating/deactivating the container is not propagated to the router (BTW: deactivated containers also do not fail requests, they simply return no data)
The Smart Router console should show the following messages:
INFO: Removed http://<KIE_SERVER_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server as server location for container com.myspace:simplebc:1.0.1-SNAPSHOT
INFO: Added http://<KIE_SERVER_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server as server location for container com.myspace:simplebc:1.0.1-SNAPSHOT

Cut off `default-kieserver` entry in smart router `/repo/kie-server-router.json` file
```
{
  ...
  "servers": [
    {"default-kieserver": ["http://<KIE_SERVER_IP_PRIVATE>:<KIE_SERVER_PORT>/kie-server/services/rest/server"]},
    **{"default-kieserver": []}**
  ]
}
```
Seems to happen when container is created on the kie server and the kie server is creating it's `<KIE_SERVER_ID>.xml` file.  
**Done**: manually deleted the file on the smart router, restarted ks.service => file on smart router is recreated ok

## Setup Validation cleanup
* remove `<SMART_ROUTER_HOME>/repo/kie-server-router.json`
* remove `<configuration>..` content from kie server id file - leave only an empty `<configuration/>`; 
the kie server will fill in the configuration part on the next restart of service/spin up of VM

## Create Smart Router and KIE Server images
See instructions at [sr-azure-setup.md](./sr-azure-setup.md) and [ks-azure-setup.md](./ks-azure-setup.md)
For kie server only do the commands under `Create the KIE Server image`. No Scale Set or Load Balancer

## Image Validation
Create 1 Smart Router VM from the smart router image and 2 Kie server VMs from the immutable, unmanaged kie server image.
Create a couple of process instances and check System.out on both servers to find the expected script message "counter:x" per instance

## VM from image Troubleshooting
### The kie server does not register with the router
When the kie server starts up for the first time on creation of the VM, the id file is configured
but the `org.kie.server.location` value is missing the host part (supposed to be the private ip of the VM
sent on start up of service, same like the port, as -D parameter to the standalone.sh)  
**Reason:** unknown  
**Fix:** restart the ks.service on the kie server VM with `sudo systemctl restart ks.service`
This will update the kie server id file (takes some time) - once the file is updated, the kie server can be
observed under the smart router
```
 <config-item>
      <name>org.kie.server.location</name>
      <value>http://:8080/kie-server/services/rest/server</value>
      <type>java.lang.String</type>
 </config-item>
```
