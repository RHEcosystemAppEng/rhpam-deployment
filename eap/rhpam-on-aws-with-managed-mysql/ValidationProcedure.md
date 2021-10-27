# Validate the deployment
We will validate the AWS deployment with the `CustomProject` project defined in [custom-business-project][0]. This includes:
* A simple `Business Project` with one skippable `Human Task`
* One extension API defined in [custom-endpoints][1]
* One `WorkItemHandler` defined in [custom-work-item-handler][2]

The validation procedure is executed through the `Smart Router` interface as much as possible. Some limitations require
anyway the use of the `KIE Server` interface:
* The `Smart Router` cannot be used to deploy new containers
* The `Smart Router` cannot be used to access custom endpoints

In order to expose the required artifacts to the `KIE Server` we have to build the Java projects from the 
`openshift/repeatableProcess` folder, and deploy them to the configured Maven repository:
```shell
mvn -s settings.xml clean install deploy
```
You can verify that the artifacts are deployed by browsing the [rhpam][4] repository on `Repsy.io`

You can use the attached [RHPAM-extensionAPI.postman_collection.json][3] to validate the whole use case.
This suite can populate automatically the required URL parameters for you, given that there are no deployment unit
on the `KIE Server` and no active processes:
* Fetch the updated `Access Token` in the RH-SSO and update the value of the `Bearer Token` in the Postman collection:
```shell
echo $(curl -s --data "grant_type=password&client_id=kie-remote&username=rhpam&password=redhat" \
http://3.83.175.221:8080/auth/realms/Temenos/protocol/openid-connect/token) | sed 's/.*access_token":"//g' | sed 's/".*//g'
```

* Create one `Environment` in Postman with the following variables:
    * `scheme`: this is usually `http` for AWS deployments
    * `smart-router-url`: the URL of the `Smart Router` endpoint root, e.g. `ec2-3-217-62-9.compute-1.amazonaws.com:9999`
    * `kieserver-url`: the endpoint root of the `KIE Server`, e.g. `3.213.33.25:8080/kie-server`
* Run the `Smart Router-List` request to verify the status of the `Smart Router`
* Run the `[KS] Delete container` request to remove the `CustomProject` container (if it was already deployed)
* Run the `[KS] Create container` request to create the `CustomProject` container
* Run the `Get containers` request to load the `containerId` parameter
* Run the `Start container` request to start the container (should already be started and return an error)
* Run the `Create instance` request to create a new instance of the `custom.process` process
  * Open the `Business Central` dashboard and browse the `Process Diagram` tab for the newly created process
* Run the `Get process instance` request to load the `processInstanceId` parameter
* Run the `Get instance details` request to load the `taskInstanceId` parameter
* Finally, run the `[KS] Custom getTask` and `[KS] Custom skip` requests to load the metadata of the given task and to skip the execution

Once completed, you can verify in the `Business Central` dashboard that the `Process Diagram` for the newly created process 
was completed, and verify that the whole process has completed the execution.

<!-- links -->
[0]: ../../openshift/repeatableProcess/custom-business-project
[1]: ../../openshift/repeatableProcess/custom-endpoints
[2]: ../../openshift/repeatableProcess/custom-work-item-handler
[3]: ./RHPAM-extensionAPI.postman_collection.json
[4]: https://repo.repsy.io/mvn/dmartino/rhpam/
