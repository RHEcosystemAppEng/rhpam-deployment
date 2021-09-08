# Table of Contents

* [s2I build for immutable kie-server with business monitoring](#s2i-build-for-immutable-kie-server-with-business-monitoring)
  * [Activate and populate the Maven mirror](#activate-and-populate-the-maven-mirror)
    * [Populate build-time dependencies](#populate-build-time-dependencies)
  * [Deploy the KieApp instance](#deploy-the-kieapp-instance)
  * [Validation procedure](#validation-procedure)
  * [Troubleshooting](#troubleshooting)
    * [Missing metadata in Nexus server](#missing-metadata-in-nexus-server)
    * [ImageStream rhpam-kieserver-rhel8-custom-mssql is invalid](#imagestream-rhpam-kieserver-rhel8-custom-mssql-is-invalid)

# s2I build for immutable kie-server with business monitoring
Purpose of this task is to define a procedure to:
* Deploy RHPAM with the Business Automation operator
* Create an immutable KIE server with the sample project defined in [custom-business-project](../repeatableProcess/custom-business-project)
* Use an external MS SQL DB
* Expose the extension API defined in [custom-endpoints](../repeatableProcess/custom-endpoints)
* Authenticate with external SSO as in [rhpamWithSSO](../rhpamWithSSO/README.md)
* ~~Maven repo mounted from shared volume on $HOME/.m2/repository~~
* Connect to an external Maven mirror via Nexus (on the same OpenShift platform)  
  * The mirror is used also to build the immutable  image of the sample project

## Activate and populate the Maven mirror
As a reference, use the instructions at [Install Maven repository on Nexus](../externalMavenRepo/README.md#install-maven-repository-on-nexus)
and [Populating Maven mirror](../externalMavenRepo/README.md#populating-maven-mirror) to activate a Nexus server and then
create a Maven mirror named `rhpam-mirror790`, populated with required dependencies for RHPAM version 7.9.0

### Populate build-time dependencies
The predefined dependencies used to populate the Maven mirror only include the ones needed at runtime.
In order to include also those required at build-time, we suggest the following procedure, that triggers the execution
of the needed Maven plugins and loads the associated dependencies in a local folder, that we can then upload to the
Maven mirror.
```shell
rm -rf ./repository
mvn -N -s settings_localrepo.xml -f ../repeatableProcess/pom.xml clean install release:clean
mvn -N -s settings_localrepo.xml -f ../repeatableProcess/custom-work-item-handler/pom.xml package
mvn -N -s settings_localrepo.xml -f ../repeatableProcess/pom.xml  help:effective
mvn -N -s settings_localrepo.xml -f ../repeatableProcess/pom.xml  dependency:go-offline

curl -O https://repo.maven.apache.org/maven2/com/simpligility/maven/maven-repository-provisioner/1.4.1/maven-repository-provisioner-1.4.1-jar-with-dependencies.jar
java --add-opens java.base/java.lang=ALL-UNNAMED \
  -jar maven-repository-provisioner-*-jar-with-dependencies.jar \
  -cd "repository" \
  -t "http://rhpam-mirror790-dmartino-immutable.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/repository/rhpam-mirror790/" \
  -u deployer \
  -p deployer123
```

The sample [settings_mirror.xml](./settings_mirror.xml) is provided for you to verify that the mirror repository contains all the
needed dependencies: just update the reference file after the `-s` option, in the above `mvn` commands, and verify they
complete as before, using the Maven mirror instead of the default Maven central repository.

**Note**: In case of any build error, you have to look at the log of the latest Pod named `immutable-custom-server-N-build`
and see if the build failure is due to any missing jar. In this case, you should repeat the steps in [](#populate-build-time-dependencies)
by providing ad-hoc file `builder.txt` containing the missing dependencies.
The following is a list of dependencies that you should be required to populate:
```text
org/codehaus/plexus/plexus-java/0.9.2/plexus-java-0.9.2.pom
org/codehaus/plexus/plexus-java/0.9.2/plexus-java-0.9.2.jar
org/codehaus/plexus/plexus-languages/0.9.2/plexus-languages-0.9.2.pom
org/ow2/asm/asm-parent/6.0_BETA/asm-parent-6.0_BETA.pom
org/ow2/asm/asm/6.0_BETA/asm-6.0_BETA.pom
org/ow2/asm/asm/6.0_BETA/asm-6.0_BETA.jar
org/codehaus/plexus/plexus-compiler/2.8.2/plexus-compiler-2.8.2.pom
org/codehaus/plexus/plexus-compilers/2.8.2/plexus-compilers-2.8.2.pom
org/codehaus/plexus/plexus-compiler-api/2.8.2/plexus-compiler-api-2.8.2.pom
org/codehaus/plexus/plexus-compiler-api/2.8.2/plexus-compiler-api-2.8.2.jar
org/codehaus/plexus/plexus-compiler-manager/2.8.2/plexus-compiler-manager-2.8.2.pom
org/codehaus/plexus/plexus-compiler-manager/2.8.2/plexus-compiler-manager-2.8.2.jar
org/codehaus/plexus/plexus-compiler-javac/2.8.2/plexus-compiler-javac-2.8.2.pom
org/codehaus/plexus/plexus-compiler-javac/2.8.2/plexus-compiler-javac-2.8.2.jar
org/apache/maven/plugins/maven-release-plugin/2.5.3/maven-release-plugin-2.5.3.pom
org/apache/maven/plugins/maven-release-plugin/2.5.3/maven-release-plugin-2.5.3.jar
```

## Deploy the KieApp instance
The reference file [custom-immutable-server-mssql-maven.template](custom-immutable-server-mssql-maven.template)
is provided as a reference for you to deploy the `KieApp` instance. You can customize it to adapt to your actual use
case, otherwise you can generate the given YAML file by executing:
```shell
sed "s/MSSQL_URL/`oc get svc mssql-service -o jsonpath="{..spec.clusterIP}:{..spec.ports[0].port}"`/g" \
  custom-immutable-server-mssql-maven.template > custom-immutable-server-mssql-maven.yaml
```
Finally, you can deploy the application as:
```shell
oc create -f custom-immutable-server-mssql-maven.yaml
```

## Validation procedure
Open the `Business Central` console from the route `immutable-custom-server-rhpamcentrmon` (`adminuser/password`),
then verify there is one server named `immutable-custom-server` with a preloaded deployment `CustomProject`.
Run the process as explained at the end of [Deploy the example Business Process](../repeatableProcess/OCP_README.md#deploy-the-example-business-process)
and validate the extension API using the procedure detailed in [Validate the extension REST API](../repeatableProcess/OCP_README.md#validate-the-extension-rest-api)

## Troubleshooting
### Missing metadata in Nexus server
Sometimes the `s2i` build can fail with a message saying that it can't find the `maven-metadata.xml` file for a given
dependency/groupID. If this is the case, you can schedule a maintenance task from the Nexus console at
`Nexus>Settings>System>Tasks` to create one of type `Repair - Rebuild Maven repository metadata (maven-metadata.xml)` 
and run it after it was configured. To accelerate the process, you can also specify the `groupID` of the artifact 
affected by the issue 

### ImageStream rhpam-kieserver-rhel8-custom-mssql is invalid 
It may happen that `immutable-custom-server` build is not started because the `rhpam-kieserver-rhel8-custom-mssql` 
ImageStream is invalid. In ths case, you can manually edit the YAML file of the ImageStream and update the property 
`specs.tags.from.name` to `quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom-mssql:7.9.0`, replacing the 
wrong namespace `rhpam-7` with the proper one.

**TODO**: open tickets
* Ticket 1: operator ignores the imageContext configuration
* Ticket 2: build-time dependencies should also be managed with ad-hoc script

