# Validate Azure Scale Set with KIE Server managed by Azure VM Scale Set
**Goal**: Validate having runtime kie-server with in an azure scale set behind an azure load balancer, we are able to 
reach the containers with every request while scaling up and down

Validation steps:  
* Create 2 instances of kie-server to start up with behind ALB
  * Create one Linux VM from RHEL 8
  * Update [deployment.properties](./deployment.properties)
  * Update and run [kie-server.sh](./kie-server.sh), [kie-server-image.sh](./kie-server-image.sh)
    * 2 KIE Server VMs are created at `10.4.0.12` and `10.4.0.15`
* Deploy and start container using REST API to call the ALB: [command](#deploy)
  * From `server.log`, the deploy goes into KIE Server at `10.4.0.12`
* Pause
  * Get containers: [command](#get-containers)
    * The result is changing, sometimes it shows one container, sometimes an empty array (but it's not using round-robin policy)
  * Stop 1 instance of kie-server
    * Stopping `10.4.0.12`
  * Perform operation on deployed process
    * Create process: [command](#create-process)
      * Fails with `Unable to create response: Container 'test_1.0.1-SNAPSHOT' is not instantiated or cannot find 
      container for alias 'test_1.0.1-SNAPSHOT'`
    * Restart `10.4.0.12` (~ 2 minutes before the service is available)
      * **Note** during this time, even if one instance is still running, the LB does not respond to new requests
  * Stop 1 instance of kie-server
    * Stopping `10.4.0.15`
  * Perform operation on deployed process
      * Create process: [command](#create-process)
          * Succeeds: new process instance ID is returned by REST and `Hello` message is logged
      * Restart `10.4.0.15`
      * Get process instances: [command](#get-process-instances)
        * Sometimes it returns the created instances, sometimes an error message: `Could not find container "test_1.0.1-SNAPSHOT`

*Outcome*: with this deployment, only one KIE Server is actually enabled to manage requests for the deployed container 

# Command references   
## Deploy
```shell
curl -X PUT "http://52.152.178.161:8080/kie-server/services/rest/server/containers/test_1.0.1-SNAPSHOT" \
  -H "accept: application/json" -H "content-type: application/json" -d \
  "{ \"container-id\" : \"test_1.0.1-SNAPSHOT\", \"release-id\" : { \"group-id\" : \"com.myspace\", \"artifact-id\" : \"test\", \"version\" : \"1.0.1-SNAPSHOT\" } }"
```
## Get containers
```shell
curl --user rhpamAdmin:redhat123# -X GET "http://52.152.178.161:8080/kie-server/services/rest/server/containers" -H "accept: application/json"
```
## Create process
```shell
  curl --user rhpamAdmin:redhat123# -X POST \
    "http://52.152.178.161:8080/kie-server/services/rest/server/containers/test_1.0.1-SNAPSHOT/processes/test.test/instances" \
    -H "accept: application/json" -H "content-type: application/json" -d "{}"
```
## Get process instances
Simple:
```shell
  curl -s --user rhpamAdmin:redhat123# -X GET \
    "http://52.152.178.161:8080/kie-server/services/rest/server/containers/test_1.0.1-SNAPSHOT/processes/instances?pageSize=1000" \
    -H "accept: application/json"
```
With extraction of `process-instance-id`:
```shell
  curl -s --user rhpamAdmin:redhat123# -X GET \
    "http://52.152.178.161:8080/kie-server/services/rest/server/containers/test_1.0.1-SNAPSHOT/processes/instances?pageSize=1000" \
    -H "accept: application/json" | jq -c -r '."process-instance"[] | ."process-instance-id" | @sh'
```