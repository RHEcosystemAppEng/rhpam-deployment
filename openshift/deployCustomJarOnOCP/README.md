# Deploy RHPAM on OpenShift with custom Kie-Server image

## Preliminary steps
Initialize the terminal session:
```shell
cd deployCustomJarOnOCP
```

## Authenticate the Red Hat Registry
Follow the instructions at [2.1. Ensuring your environment is authenticated to the Red Hat registry](https://access.redhat.com/documentation/en-us/red_hat_process_automation_manager/7.11/html-single/deploying_red_hat_process_automation_manager_on_red_hat_openshift_container_platform/index#registry-authentication-proc_openshift-operator)
to download the YAML definition of one Registry Service Account for Shared  Environments and then install it.

**Prerequisites**
* You are logged into the OpenShift project
* You downloaded the secret file from Red Hat registry as rh.registry-secret.yaml

```sh
oc create -f rh.registry-secret.yaml
RH_SECRET_NAME=$(grep name rh.registry-secret.yaml | sed -e 's/.*: //')
oc secrets link default ${RH_SECRET_NAME} --for=pull
oc secrets link builder ${RH_SECRET_NAME} --for=pull
```
## Authenticate the Quay.io Registry
To Quay.io:
Save secret definition from Settings>Generate Encrypted Password and save as `<ROOT of temenos-rhpam7>/openshift/quay.io-secret.yaml`
```shell
oc create -f quay.io-secret.yaml
QUAYIO_SECRET_NAME=$(grep name quay.io-secret.yaml | sed -e 's/.*: //')
oc secrets link default ${QUAYIO_SECRET_NAME} --for=pull
oc secrets link builder ${QUAYIO_SECRET_NAME} --for=pull
````

## Create secrets
Launch the following script to create the certificate for the RHPAM services and deploy them as OpenShift secrets:
```shell
./secrets.sh
```

This will create the following secrets and entries in the OpenShift project:

| Service      | Certificate Name |  Password | Secret Name |
| ----------- | ----------- | ----------- | ----------- |
| KIE Server | kieserver |kieserver-pass | kieserver-app-secret |
| Business Central | businesscentral |businesscentral-pass | businesscentral-app-secret |
| AMQ Broker | broker |broker-pass | broker-app-secret |
| Smart Router | smartrouter |smartrouter-pass | smartrouter-app-secret |

**Note**: all the keystores must be named keystore.jks
All the certificates have the same distinguished name: `CN=dmartino.redhat.com,OU=Ecosystem Engineering,O=redhat.com,L=Raleigh,S=NC,C=US`
You can update the file to configure it with different options.

## Installing using the Operator
**Prerequisites**: Install the Business Automation operator.

Use the following command to create the KieApp instance that triggers the creation of all the RHPAM resources through the 
Business Automation operator:
```shell
oc create -f custom-rhpam.yaml
```
Use the given `custom-rhpam.yaml` file as a reference and customize it for your purposes.
The reference configuration has:
* 2 replicas for the RHPAM Business Central Monitoring
* 2 replicas for the KIE Server with name `kieserver-1`
* Deploy a custom image located at [quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.11.0-4](quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.11.0-4)
** Note: the image has private access, so we have to configure the token as a secret to access it 
  (see above step `Authenticate the Quay.io Registry`)   
* Deploy a MySQL database to store the KIE Server state

Validate that the installation completes when all the Pods are in `Running` or `Completed` state.

## Accessing the Business Central Monitoring application
The URL of the application can be found as:
```shell
oc get route -o jsonpath='{..spec.host}{"\n"}' custom-rhpam-rhpamcentrmon
```
In alternative, launch the application by clicking on the `Location` column of the route named 
`custom-rhpam-rhpamcentrmon` in the `Networking>Routes` menu of the OCP console.

**Note**: the route name can be `<name>-rhpamcentrmon` if you changed the instance name in the given
`custom-rhpam.yaml` configuration

**Note**: default username is `admin`, with password `password`

**Note**: unless you configured the application with a signed certificate, you will be asked to
trust the execution of the application published with a self-signed certificate

## Cleanup the configuration
Execute the following commands to cleanup all the deployed resources and configurations:
```shell
oc delete -f custom-rhpam.yaml
RH_SECRET_NAME=$(grep name rh.registry-secret.yaml | sed -e 's/.*: //')
oc secrets unlink default ${RH_SECRET_NAME} 
oc secrets unlink builder ${RH_SECRET_NAME}
oc delete secret/${RH_SECRET_NAME}
QUAYIO_SECRET_NAME=$(grep name quay.io-secret.yaml | sed -e 's/.*: //')
oc secrets unlink default ${QUAYIO_SECRET_NAME} 
oc secrets unlink builder ${QUAYIO_SECRET_NAME}
oc delete secret/${QUAYIO_SECRET_NAME}
oc delete is/rhpam-kieserver-rhel8-custom
```

In alternative, you can remove the entire project with:
```shell
oc delete project PROJECT_NAME
```

### Troubleshooting 
#### Keystore issues
* If you update the keystore password, it must match with the one in the `common.keyStorePassword` section of the YAML 
  configuration
* The expected keystore type must be JKS
#### Verifying the custom image
The following command verifies that the expected libraries have been installed in one of the deployed 
KIE Server pods:
```shell
PODNAME=$(oc get pods | grep custom-kieserver | grep -v "deploy\|mysql" | head -1 | cut -d " " -f1)
oc exec ${PODNAME} -- ls /opt/eap/standalone/deployments/ROOT.war/WEB-INF/lib/ | grep "Get"
```
### Issues with custom image
If the KIE Server pods are not deployed, you can verify the state of the `ImageStream` instance named
`rhpam-kieserver-rhel8-custom`, either in the console or by running:
```shell
oc describe is/rhpam-kieserver-rhel8-custom
```
In case of errors, verify that the custom image is available on the `Quay.io` repository and
you performed the steps in section `Authenticate the Quay.io Registry`.
You can validate the state of the related `ServiceAccount` instances by running:
``sh
oc describe sa default
oc describe sa builder
``

Both of them must report the name of the installed secrets in the section `Image pull secrets`.
Try to run again the initial steps in case they are missing.

If the problem persists, you can manually import the image as:
```shell
oc import-image rhpam-kieserver-rhel8-custom:7.11.0-4 \
--from=quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.11.0-4 --confirm
```
Then, cleanup all resources following the instructions in section `Cleanup the configuration`
and repeat again the configuration steps from `Authenticate the Red Hat Registry`.
