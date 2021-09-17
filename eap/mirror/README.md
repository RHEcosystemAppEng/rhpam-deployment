# Table of Contents
* [Use RHPAM on Standalone EAP to deploy temenos artifacts from the nexus mirror repository](#use-rhpam-on-standalone-eap-to-deploy-temenos-artifacts-from-the-nexus-mirror-repository)
  * [Install the Extension API](#install-the-extension-api)
  * [Define Maven settings](#define-maven-settings)
  * [Configure Maven properties](#configure-maven-properties)
  * [Start EAP](#start-eap)
  * [Validate the deployment](#validate-the-deployment)

# Use RHPAM on Standalone EAP to deploy temenos artifacts from the nexus mirror repository
Specs:
* Nexus mirror is: http://rhpam-mirror790-dmartino-immutable.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/repository/rhpam-mirror790/
* Mirror is populated with:
  * Business project: com.testspace:CustomProject:1.0.0
  * Work item handler: com.redhat.ecosystem.appeng.fsi:custom-work-item-handler:1.0.0-SNAPSHOT
  * Extension API: 

## Install the Extension API
Build the [custom-endpoints](../../openshift/repeatableProcess/custom-endpoints) or download the latest artifact from the 
Nexus mirror, then install it in EAP as:
```shell
cp custom-endpoints-1.0.0-SNAPSHOT.jar JBOSS_HOME/standalone/deployments/kie-server.war/WEB-INF/lib/
````

## Define Maven settings
Save the content of this file in a local folder like `/opt/mirror`
```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">
    <mirrors>
        <mirror>
            <id>central-proxy</id>
            <name>Local proxy of central repo</name>
            <url>
		http://rhpam-mirror790-dmartino-immutable.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/repository/rhpam-mirror790
            </url>
            <mirrorOf>central</mirrorOf>
        </mirror>
    </mirrors>
</settings>
```
## Configure Maven properties
Add the following properties under `system-properties` in `JBOSS_HOME/standalone/configuration`:
```xml
<property name="kie.maven.settings.custom" value="/opt/mirror/settings.xml"/>
<property name="org.appformer.m2repo.url" value="http://rhpam-mirror790-dmartino-immutable.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/repository/rhpam-mirror790"/>
```

## Start EAP
```shell
cd JBOSS_HOME/bin
./standalone.sh -c standalone-full.xml
```

## Validate the deployment
Follow these steps to deploy the custom project and validate both the custom Work Item Handler and the Extension API:
* [Deploy the example Business Process](../../openshift/repeatableProcess/OCP_README.md#deploy-the-example-business-process) 
* [Validate the extension REST API](../../openshift/repeatableProcess/OCP_README.md#validate-the-extension-rest-api)  