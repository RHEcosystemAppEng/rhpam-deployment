# Table of Contents
* [Configure RHPAM with External Maven Repo](#configure-rhpam-with-external-maven-repo)
  * [Install Maven repository on Nexus](#install-maven-repository-on-nexus)
    * [Testing locally](#testing-locally)  
  * [Populating Maven mirror](#populating-maven-mirror)  
  * [Deploying RHPAM application](#deploying-rhpam-application)
    * [Preliminary steps](#preliminary-steps)
    * [Validating the deployment](#validating-the-deployment)

# Configure RHPAM with External Maven Repo
**Prerequisites**:
* Create new project `dmartino-maven`

This procedure is meant to deploy an instance of RHPAM with the following features:
* rhpam-authoring environment
* Business Central, KIE Server and Smart Roter run a image of version 7.0.9 from RH Registry

## Deploying RHPAM application
### Preliminary steps
* Install the `Business Automation` operator
* From previous examples, perform these steps:
  * [Create secrets](../deployCustomJarOnOCP/README.md#create-secrets).

Customize the provided [rhpam-7.0.9.yaml](./rhpam-7.0.9.yaml) configuration to match your
requirements.

### Validating the deployment 
Launch the Route named `rhpam-790-rhdmcentr` (or `<KIEAPP-NAME>-rhpamcentr` if you are using a different 
name) and connect the instance using `admin/password` credentials.
Verify that you can design and deploy a new application .

To verify the image version, read it from the `oc describe image` of each running image, as in the following example:
```shell
oc get pods -o jsonpath='{..spec.containers[0].image}{"\n"}'
oc describe image sha256:a636cb2c183ce14d7985dfc1efb0d4ad636c0ff6c07a8246d7e38c4092fe561e | grep -i version
```