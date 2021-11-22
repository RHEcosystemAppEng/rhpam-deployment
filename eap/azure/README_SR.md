# Smart Router deployment runbook
Purpose of this project is to define a mostly automated procedure to create KIE servers accessed via Smart Router on the Azure platform.

Options supported are:
* Runtime environment:
  * Unmanaged, immutable RHPAM KIE Server
  * Unmanaged RHPAM Smart Router
  * This environment is used to run a scalable architecture of KIE Server instances managing the projects defined at
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
ssh -i <SSH_PEM_FILE> azureuser@SMART_ROUTER_SERVER_IP sudo journalctl -u ks.service -f
```

## Deploy and configure the Kie Server
The following command will deploy on the KIE Server VM all the required software and then install and configure both
`EAP JBoss 7.3` and `RHPAM 7.9.0`:
```shell
./kie-server.sh UNMANAGED_WITH_SMARTROUTER
```
**Notes**: the UNMANAGED_WITH_SMARTROUTER parameter will install a kie server without controller properties
Apart from that the installation is the same described here [Deploy and configure the KIE Server](README.md)

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
    {"simplebc": ["http://fsi-smart-router-unmgd-kie-server:8080/kie-server/services/rest/server"]},
    {"com.myspace:simplebc:1.0.1-SNAPSHOT": ["http://fsi-smart-router-unmgd-kie-server:8080/kie-server/services/rest/server"]}
  ],
  "servers": [{"default-kieserver": ["http://fsi-smart-router-unmgd-kie-server:8080/kie-server/services/rest/server"]}]
}
```

## Provision the kie server
#### Add artifacts
Create a container file to upload to the kie server:
```
create-container.xml:
<script>
    <create-container>
        <container container-id="com.myspace:simplebc:1.0.1-SNAPSHOT">
            <release-id>
                <group-id>com.myspace</group-id>
                <artifact-id>simplebc</artifact-id>
                <version>1.0.1-SNAPSHOT</version>
            </release-id>
            <config-items>
                <itemName>RuntimeStrategy</itemName>
                <itemValue>PER_PROCESS_INSTANCE</itemValue>
                <itemType></itemType>
            </config-items>
        </container>
    </create-container>
</script>

curl -v -X POST -H 'Content-type: application/xml' -H 'X-KIE-Content-Type: xstream' -d @create-container.xml \ 
-u rhpamAdmin:redhat123# http://<KIE_SERVER_IP>:<KIE_SERVER_PORT>/kie-server/services/rest/server/config/
```
#### Remove public IP
Enter on Azure resource `Public IP address` of the kie server. Click `Dissociate` in top menu.

## Smart router tweaks after validation tests
#### Remove kie server file
The first Kie server getting to the Smart router causes a registration file `kie-server-router.json` to be created where
the Smart Router keeps taps on the registered servers.
The change will only be visible after restart of the sr.service.
```
ssh -i ${SSH_PEM_FILE} azureuser@${SMART_ROUTER_SERVER_IP} "sudo rm <SMART_ROUTER_HOME>/repo/kie-server-router.json"

Open `http://SMART_ROUTER_HOST:SMART_ROUTER_PORT/mgmt/list`
Response should be:

{
"containerInfo": [],
"containers": [],
"servers": []
}
```

## Create Smart Router and KIE Server images
See instructions at [sr-azure-setup.md](./sr-azure-setup.md) and [ks-azure-setup.md](./ks-azure-setup.md)
For kie server only do the commands under `Create the KIE Server image`. No Scale Set or Load Balancer

## Image Validation
Create 1 Smart Router VM from the smart router image and 2 Kie server VMs from the immutable, unmanaged kie server image.
Create a couple of process instances and check System.out on both servers to find the expected script message "counter:x" per instance
```

```

