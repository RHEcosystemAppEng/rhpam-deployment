# Table of Contents
* [Create production grade Nexus repository](#create-production-grade-nexus-repository)
  * [Configure the rhpam-mirror790 repository](#configure-the-rhpam-mirror790-repository)
  * [Populate Maven mirror](#populate-maven-mirror)
  * [Validation](#validation)
* [Troubleshooting](#troubleshooting)
  * [Find default admin password](#find-default-admin-password) 
  * [Missing Maven metadata](#missing-maven-metadata)

# Create production grade Nexus repository
"Create production grade nexus repo that can act as mirror repo for maven artifacts"

The reference [nexus-mirror.yaml](./nexus-mirror.yaml) defines a configuration to deploy the Nexus repository manager
with:
* PersistentVolumeClaim: `nexus-mirror-data`, 8Gi
* Deployment: `nexus-mirror`
  * Image is `sonatype/nexus-repository-manager`
  * Path /nexus-data is mounted on the `nexus-mirror-data` PersistentVolumeClaim
* Service: `nexus-mirror`

Run the following to deploy the needed resources and expose the Route:
```shell
oc create -f nexus-mirror.yaml
oc expose service/nexus-mirror
```

By accessing the URL of the Route we can manage the application.

## Configure the rhpam-mirror790 repository
Follow these instructions to initialize the Nexus repository: [Install Maven repository on Nexus](../externalMavenRepo#install-maven-repository-on-nexus)

## Populate Maven mirror
Follow these instructions to initialize the Nexus repository: [Populating Maven mirror](../externalMavenRepo#populating-maven-mirror)
**Note**: you have to change the URL in the Maven provisioner command to match the actual Route, like:
```shell
java --add-opens java.base/java.lang=ALL-UNNAMED \
-jar maven-repository-provisioner-*-jar-with-dependencies.jar \
-cd "repository" \
-t "http://nexus-mirror-dmartino-nexus-sonatype.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/repository/rhpam-mirror790/" \
-u deployer \
-p deployer123
```

## Validation
Update the Maven [settings.xml](../repeatableProcess/settings.xml) by adding a `<mirrors>` section like this:
```xml
    <mirrors>
        <mirror>
            <id>central-proxy</id>
            <name>Local proxy of central repo</name>
            <url>
		http://nexus-mirror-dmartino-nexus-sonatype.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/repository/rhpam-mirror790
            </url>
            <mirrorOf>central</mirrorOf>
        </mirror>
    </mirrors>
```
Then build the Maven project verifying that the artifacts are downloaded from the newly created mirror:
```shell
cd ../repeatableProcess
mvn -s settings.xml -U clean install
```
The console output shows where the artifacts are downloaded from, like:
```shell
...
Downloaded from central-proxy: http://nexus-mirror-dmartino-nexus-sonatype.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/repository/rhpam-mirror790/org/sonatype/sisu/sisu-inject-bean/2.3.0/sisu-inject-bean-2.3.0.pom (0 B at 0 B/s)
...
```

# Troubleshooting
## Find default admin password
Run the following to print the default password of the Nexus repository manager:
```shell
oc exec `oc get pods -o jsonpath='{..metadata.name}{"\n"}' --selector=deployment=nexus-mirror` -- cat /nexus-data/admin.password
```
## Missing Maven metadata 
After the initial population, the Maven build can fail because Nexus needs to generate all the Maven metadata for the
bunch of artifacts uploaded at population time. 

If we can identify what are the missing artifacts, and if we can verify 
that they are instead published in the `rhpam-mirror790` repository, it might be the case that the `maven-metadata.xml` file
is missing. 
We can force the generation from `Nexus>Administration>System>Tasks` menu, then we create one task of type 
`Repair - Rebuild Maven repository metadata (maven-metadata.xml)`, possibly configured for a single `groupId` or `groupId` 
and `artifactId`, with `Manual` schedule and run it manually. 

After few minutes, the missing metadata are generated and we can try again the Maven build.
