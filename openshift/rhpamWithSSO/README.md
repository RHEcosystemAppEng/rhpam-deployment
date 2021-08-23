# Table of Contents
* [Installation of RHPAM with RHSSO configuration](#creating-a-rhpam-installation-with-rhsso-configuration)
    * [Installation and configuration of RHSSO](#installation-and-configuration-of-rhsso)
    * [Installation and configuration of RHPAM](#installation-and-configuration-of-rhpam)

# Creating a RHPAM installation with RHSSO configuration

## Installation and configuration of RHSSO
* Install Red Hat Single Sign-On Operator
  Use the following command to create the Keycloak instance:
```shell
oc create -f rhsso.yaml
```

Validate that the installation completes when all the Pods are in `Running` or `Completed` state.

* Access the Keycloak admin console using the keycloak route, for example **https://keycloak-theom.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com**.
**note** Go to the secret with your key cloak name and use the ADMIN_PASSWORD and ADMIN_USER to login to the keycloak admin console.
* Create a realm, for example **demo**
* Create roles (admin, kie-server, rest-all) in the realm
* Create a user for example **adminuser**
* Edit the user, go to credentials set its password, uncheck temporary   
* Edit the user, go to role mapping and assign the roles you previously created (admin, kie-server, rest-all)
* Create a client for Business central, edit the client info, change access type to confidential, input Root URL and Valid Redirect URIs to point to the Business central route URL for example **https://rhpam-test-rhpamcentrmon-theom.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com** and __https://rhpam-test-rhpamcentrmon-theom.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/*__
* Create a client for the Kie Server, edit the client info, change access type to confidential, input Root URL and Valid Redirect URIs to point the Kie Server route URL for example **https://rhpam-test-kieserver-theom.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com** and __https://rhpam-test-kieserver-theom.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/*__

## Installation and configuration of RHPAM
* Install Red Hat Business Automation Operator
Use the following command to create the KieApp instance that triggers the creation of all the RHPAM resources through the
Business Automation operator:
```shell
oc create -f rhpam-with-sso.yaml
```
Use the given `rhpam-with-sso.yaml` file as a reference with placeholders, replace the placeholders with your own parameters.
The reference configuration has:
* 1 replica for the RHPAM Business Central
* 1 replicas for the KIE Server with name `kieserver`

rhpam-with-sso.yaml parameters:

* In commonConfig section the adminUser and adminPassword should be the same as the of the user and password you created in Keycloak.
* In sso section the url should be the <keycloak route name>/auth.
* In sso section the realm should be the realm you created in keycloak.
* In sso section the adminUser and adminPassword should be the same as the of the user and password you created in Keycloak.
* In **console** section under ssoClient section the name parameter should be the Business central client name you created in keycloak.
* In **console** section under ssoClient section the secret parameter should be the Business central client secret which can be found in keycloak when editing the client, it's in Credentials tab.
* In **servers** section under ssoClient section the name parameter should be the Kie Server client name you created in keycloak.
* In **servers** section under ssoClient section the secret parameter should be the Kie Server central client secret which can be found in keycloak when editing the client, it's in Credentials tab.

Validate that the installation completes when all the Pods are in `Running` or `Completed` state.

## Accessing the Business Central application
The URL of the application can be found as:
```shell
oc get route -o jsonpath='{..spec.host}' rhpam-test-rhpamcentrmon
```
In alternative, launch the application by clicking on the `Location` column of the route named
`rhpam-test-rhpamcentrmon` in the `Networking>Routes` menu of the OCP console.

**Note**: the route name can be `<name>-rhpamcentrmon` if you changed the instance name in the given
`rhpam-with-sso.yaml` configuration
