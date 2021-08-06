# Table of Contents

* [Phase 2: deploying on OCP](#phase-2-deploying-on-ocp)
  * [Updates from existing procedures](#updates-from-existing-procedures)
  * [Configuring Maven repositories](#configuring-maven-repositories)
    * [External Maven repository on Repsy](#external-maven-repository-on-repsy)
    * [Maven mirror on OCP](#maven-mirror-on-ocp)
  * [Custom KIE Server image](#custom-kie-server-image)
      * [Building the required artifacts](#building-the-required-artifacts)
      * [Building the custom KIE Server image with Podman on MacOS](#building-the-custom-kie-server-image-with-podman-on-macos)
  * [Configuring the MS SQL database](#configuring-the-ms-sql-database)
    * [Deploying the MS SQL dinstance](#deploying-the-ms-sql-dinstance)
    * [Generate the custom MS SQL image](#generate-the-custom-ms-sql-image)
  * [Deploying RHPAM on OCP](#deploying-rhpam-on-ocp)
    * [Pushing the required images](#pushing-the-required-images)
    * [Deploying the KeiApp instance](#deploying-the-keiapp-instance)
  * [Validation procedure](#validation-procedure)
    * [Deploy work-item-service on OCP](#deploy-work-item-service-on-ocp)
    * [Verify the custom library is installed](#verify-the-custom-library-is-installed)
    * [Verify the MS SQL driver is installed](#verify-the-ms-sql-driver-is-installed)
    * [Deploy the example Business Process](#deploy-the-example-business-process)
    * [Validate the extension REST API](#validate-the-extension-rest-api)

# Phase 2: deploying on OCP
## Updates from existing procedures
* Secrets are not deployed on OCP because RHPAM is not publihing HTTPS services
* Reference version is 7.9.0, which affects all the different parts involved with the deployment (Maven, MS SQL)
* Maven repo is configured on Repsy
* Nexus is deployed from official operator provided by Sonatype

## Configuring Maven repositories
### External Maven repository on Repsy
Register a free account on [Repsy](https://repsy.io/) and create a Maven repository called `rhpam`.
Our reference repository is defined for user `dmartino/dMartino123` at the URL `https://repo.repsy.io/mvn/dmartino/rhpam`.

### Maven mirror on OCP
The following instructions provision the required Maven repository on a Nexus instance deployed on OCP:
* Install the `Nexus Repository Operator  3.32.0-1 provided by Sonatype` on the OpenShift project
* Click on the operator and create a new `NexusRepo` instance named `rhpam-mirror`
* Launch the route named `rhpam-mirror` and connect the Nexus with credentials `admin/admin123`
* Refer to [How to upload the artifacts in Sonatype Nexus using Maven](https://www.devopsschool.com/blog/how-to-upload-the-artifacts-in-sonatype-nexus/)
  to generate:
  * a new role `deploy` with privileges `nx-all`
  * a user `deployer/deployer123` with role `deploy`
  * [login as `deployer`]
  * a repository `rhpam-mirror790` of type `maven2/hosted` with policy `Mixed`

**Note**: the mirror repository must be publicly accessible:
```text
The repository must allow read access without authentication
```
This can be achieved by enabling the following setting in the Nexus instance:
`Settings>Anonymous Access>Allow anonymous users to access the server`

The mirror repository is then populated with all the required dependencies, starting from the [Software Downloads](https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=rhpam&productChanged=yes)
page for `Process Automation Manager 7.9.0`, where we can download the `Red Hat Process Automation Manager 7.9.0 Offliner Content List`,
e.g. [rhpam-7.9.0-offliner.zip](https://access.redhat.com/jbossnetwork/restricted/softwareDownload.html?softwareId=89611).
Run the following commands to setup a Pod that runs the repository population procedure:
```shell
oc run offliner --image openjdk/openjdk-11-rhel7 -- tail -f /dev/null
oc exec offliner -- mkdir /opt/offliner
oc rsync . offliner:/opt/offliner --exclude="*" --include=rhpam-7.9.0-offliner.zip
```
From the OCP administration console, open the `Terminal` page of the `offliner` Pod and execute the steps to initialize
the list of required artifacts and push them on the `rhpam-mirror790` repository of Nexus. The repository is populated using
the [Maven Repository Provisioner](https://github.com/simpligility/maven-repository-tools/tree/master/maven-repository-provisioner)
project:
```shell
cd /opt/offliner
unzip rhpam-7.9.0-offliner.zip
cd rhpam-7.9.0-offliner
# Note: replace 'wget' with 'curl -O'
sed -i 's/wget/curl -O/g' offline-repo-builder.sh
./offline-repo-builder.sh offliner.txt

curl -O https://repo.maven.apache.org/maven2/com/simpligility/maven/maven-repository-provisioner/1.4.1/maven-repository-provisioner-1.4.1-jar-with-dependencies.jar
java --add-opens java.base/java.lang=ALL-UNNAMED \
  -jar maven-repository-provisioner-*-jar-with-dependencies.jar \
  -cd "repository" \
  -t "http://rhpam-mirror-dmartino-immutable.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/repository/rhpam-mirror790" \
  -u deployer \
  -p deployer123
```

## Custom KIE Server image
### Building the required artifacts
The following commands build all the required artifacts and deploy them on the Maven repository and mirror:
* [custom-endpoints](./custom-endpoints): the custom extension API to integrate in the KIE Server image
  * Note: this artifact is not deployed on the Maven repository
* [custom-work-item-handler](./custom-work-item-handler): the custom `WorkItemHandler` exposing the `ItemsLoader` item
  * Note: you have to update the URL in `ItemsLoaderWorkItemHandler.java` to point to the actual route of the
`work-item-service` deployment
* [work-item-service](./work-item-service): the example REST API queried by the `ItemsLoader` item
  * Note: this artifact is not deployed on the Maven repository
* [custom-business-project](./custom-business-project): the custom Business Process using the `Items Loader` item (this was 
pulled from the initial [EAP deployment](./EAP_README.md) using `git clone ssh://rhpamAdmin@localhost:8001/testSpace/custom`)

```shell
mvn -s settings.xml clean package deploy
mvn -s settings.xml deploy -Dmirror
```

### Building the custom KIE Server image with Podman on MacOS
Requirements:
* [Vagrant](https://www.vagrantup.com/downloads)
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* Install Podman client as `brew install podman`

* The following instructions are defined to generate a custom KIE Server image including the extension API defined in the
[custom-endpoints](./custom-endpoints) project and described [here](./EAP_README.md#develop-deploy-and-test-the-extension-api).

Configure Vagrant to use the current configuration:
```sh
cd <ROOT FOLDER OF temenos-rhpam7>/01-createCustomKierServerImage
export VAGRANT_CWD=$PWD
export CONTAINER_HOST=ssh://vagrant@127.0.0.1:2222/run/podman/podman.sock
export CONTAINER_SSHKEY=$PWD/.vagrant/machines/default/virtualbox/private_key

vagrant up
```

Verify that the `Podman API Service` service is running:
```shell
vagrant ssh default
systemctl status podman
```
The output should be similar to:
```shell
● podman.service - Podman API Service
     Loaded: loaded (/usr/lib/systemd/system/podman.service; static)
     Active: active (running) since Wed 2021-08-04 09:40:07 UTC; 2s ago
TriggeredBy: ● podman.socket
       Docs: man:podman-system-service(1)
   Main PID: 1728 (podman)
      Tasks: 7 (limit: 1132)
     Memory: 23.6M
        CPU: 81ms
     CGroup: /system.slice/podman.service
             └─1728 /usr/bin/podman --log-level=info system service
```

Then, connect the Podman client to the service running on the virtual box, and verify the connection is provisioned:
```shell
podman system connection add fedora33 ssh://vagrant@127.0.0.1:2222
podman system connection list
```

From the local terminal, run the next commands to login to Red Hat and Quay registries, build the custom image using the reference
[Dockerfile](./Dockerfile) and push it on the Quay registry, under the `ecosystem-appeng` group:
```shell
podman login -u='11009103|dmartino' \
-p=eyJhbGciOiJSUzUxMiJ9.eyJzdWIiOiJjNjEwOWJjZjcyNjU0ODQzODFiNzUzMzhjNzJmZGExNiJ9.p0KBU_Mn8S5hxQcgSqIj1mac6_c5oc1YY9owoIPzm0eyICdLMej5Jt8BoKFYpn1Pn4alqjQZTzrK3RSg9EM1SHDpLdqS70yEgMObGt62mFNsapRfw6h1F7V7JkS-J9L23jweKX6pfs4L0zgQhsckBVNj7UU-DVnDkHBE3C7-I7bPR92MAy53Po4eon9pV_cj0iWOzGrj7nCVNiQRDFj_AceHGz-A9EgbCH4Itwfa-02zQz7q2I3tzbIAkhGC9nlZq_rtJG96ULTc8wVuNDXznX81q1MpuLTjwpleASF8PEuFILpZlPpfqX-fsO27_EFOkzGzI_EuCs1xpqfgj7wvIWRD3mef7jWQl3mDIUqC5h6xE6b5ofTBj8MMX3-gDTHUA6fJ1JUdmWrkygh8MqN1gAxfHJ7L3i1nfFVEKntkRr_TFLmxzbAjXuB0TuTi9H34BwSDrnj0FAoLSIjOMvjcVKFRKmj_0VpqIesQW61zJssQZRqaMaYEJNXjsUu3QMBaNPgh3ukiJ-t-rxmefCF8c5MSMtpbR_FOrpLmIFq5ft3LifUdfbTQc4tOwZ6KlJLM2geOQxZT2R3mEmqkKWEnaIQXn_w6W7-m6x1E1HDkUkdhYM5VqlwRMm4VPl9uJXoRuB4d7YYGjWEzUZF7nUMxTQzE7OOJ7DypefIPHc8mVpI registry.redhat.io
podman build -t quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.9.0 .

podman login quay.io
podman push quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.9.0
```

Verify the build was successfully generated and deployed by running `podman images` and looking at the repository details
on [Quay](https://quay.io/repository/ecosystem-appeng/rhpam-kieserver-rhel8-custom?tab=tags)

## Configuring the MS SQL database
### Deploying the MS SQL dinstance
**Note**: These steps are optional if you already have your own running instance of MS SQL server (either as an OpenShift
container or as a standalone service).

* [Deploy MS SQL instance](../msSqlServerDatabase/README.md#deploy-ms-sql-instance)
* [Create the RHPAM database and validate the MS SQL installation](../msSqlServerDatabase/README.md#create-the-rhpam-database-and-validate-the-ms-sql-installation)

### Generate the custom MS SQL image
** References**:
* [2.6. Building a custom KIE Server extension image for an external database](https://access.redhat.com/documentation/en-us/red_hat_process_automation_manager/7.9/html-single/deploying_red_hat_process_automation_manager_on_red_hat_openshift_container_platform/index#externaldb-build-proc_openshift-operator)
**Note**: this section is different from [Build the custom KIE Server extension image](../msSqlServerDatabase/README.md#build-the-custom-kie-server-extension-image)
because is targetted to version 7.9.0 of RHPAM.
* 
Run The following commands to setup the development environment 
```shell
virtualenv ~/cekit3.2
source ~/cekit3.2/bin/activate
pip install 'cekit==3.2'
curl -O https://raw.githubusercontent.com/cekit/cekit/3.2.0/requirements.txt
pip install -r requirements.txt
pip install docker
pip install docker-squash
pip install behave
pip install lxml
pip install odcs
```
From the `Software Downloads` page for version `7.9.0`, download the archive for
[Red Hat Process Automation Manager 7.9.0 OpenShift Templates](https://access.redhat.com/jbossnetwork/restricted/softwareDownload.html?softwareId=89641).
Then extract the content and run the command to generate the extension image:
```shell
unzip -d rhpam-7.9.0-openshift-templates rhpam-7.9.0-openshift-templates.zip
cd rhpam-7.9.0-openshift-templates/templates/contrib/jdbc/cekit
make mssql
```
Validate the image is created:
```shell
docker images | grep jboss-kie-mssql-extension-openshift-image
```
## Deploying RHPAM on OCP
### Pushing the required images
Tag and push the KIE Server custom image (downloaded from Quay if not already there) and the JDBC extension image to
your OCP namespace (`oc project -q`):
```shell
OCP_REGISTRY=$(oc get route -n openshift-image-registry | grep image-registry | awk '{print $2}')
docker login  -u `oc whoami` -p  `oc whoami -t` ${OCP_REGISTRY}

docker login quay.io
docker pull quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.9.0
docker tag quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.9.0 \
    ${OCP_REGISTRY}/`oc project -q`/rhpam-kieserver-rhel8-custom:7.9.0
docker tag kiegroup/jboss-kie-mssql-extension-openshift-image:7.2.2.jre11 \
    ${OCP_REGISTRY}/`oc project -q`/jboss-kie-mssql-extension-openshift-image:7.2.2.jre11
    
docker push ${OCP_REGISTRY}/`oc project -q`/rhpam-kieserver-rhel8-custom:7.9.0
docker push ${OCP_REGISTRY}/`oc project -q`/jboss-kie-mssql-extension-openshift-image:7.2.2.jre11
```

### Deploying the KeiApp instance
* Install the `Business Automation` operator
* Run the following command to deploy the sample application:
```shell
oc create -f custom-rhpam-mssql-maven.yaml
```

**Note**: you probably need to update the given [custom-rhpam-mssql-maven.yaml](./custom-rhpam-mssql-maven.yaml) configuration to
adapt the environment parameters to match your actual setup (e.g., Maven and MS SQL location, OCP namespace and so on)

The provided configuration generates an RHPAM setup with the following features:
* Environment: `rhpam-production`
* Base images: 7.9.0
* Custom KIE Server image with new endpoint APIs
* External Maven repository `rhpam` on Repsy
* Mirror Maven repository `rhpam-mirror` on OCP
* MS SQL database
* No `Smart Router`

## Validation procedure
### Deploy work-item-service on OCP
Run the following commands to deploy the sample REST API `work-item-service` on the OCP platform:
```shell
cd work-item-service
mvn quarkus:add-extension -Dextensions="openshift"
mvn clean package -Dquarkus.kubernetes.deploy=true
```

**Note**: The following settings are required in `application.properties`:
```properties
quarkus.openshift.expose=true
quarkus.kubernetes-client.trust-certs=true
```

### Verify the custom library is installed
The following commands verify the proper installation of the `custom-endpoints` extension API and checks there are no
errors in the log of the Pod:
```shell
oc exec `oc get pods | grep custom-kieserver | grep Running | awk '{print $1}'` \
  -- ls /opt/eap/standalone/deployments/ROOT.war/WEB-INF/lib/custom-endpoints-1.0.0-SNAPSHOT.jar
oc logs `oc get pods | grep custom-kieserver | grep Running | awk '{print $1}'` | grep CustomApplicationComponentsService
```

### Verify the MS SQL driver is installed
The following commands verify the proper installation of the MS SQL driver in the KIE Server Pod:
```shell
oc exec -it `oc get pods | grep custom-kieserver | grep Running | awk '{print $1}'` -- ls /opt/eap/modules/com/microsoft/main
```

### Deploy the example Business Process
From the `Business Central Monitor` application available for the route `custom-rhpam-mssql-maven-rhpamcentrmon` (`admin/password`),
go to `Execution Servers` and add a new `Deployment Unit` with these settings:
```text
Name: CustomProject
Group Name: com.testspace
Artifact Id: CustomProject
Version: 1.0.0
```
Verify the deployment unit has no errors on the console and by monitoring the log file:
```shell
oc logs -f `oc get pods | grep custom-kieserver | grep Running | awk '{print $1}'` 
```

Then, start a new  `Process Instance`, selecting the `custom.process` process.
Once started, open the instance and verify the `Process Variables` tab contains the expected values for every variable.
Finally, open the `Process Diagram` tab and verify that the process is waiting on ythe `humanTask` task. 

### Validate the extension REST API
You can use the attached [Postman collection scripts](./custom-endpoints/RHPAM-extensionAPI.postman_collection.json) to 
validate the extension REST APIs, or to serve as a reference and adopt your own REST client.

This suite can populate automatically the required URL parameters for you, given that there is only one deployment unit
on the KIE Server and only one active process:
* Create one `Environment` in Postman with the following variables:
  * `kieserver-url` taken from the location of the `custom-kieserver` route exposed in OCP
  * `scheme` which is usually `https` for OCP deployments and `http` for local/EAP deployments
* Run the `Get containers` request to load the `containerId` parameter (should be `CustomProject`, if you followed the above instructions)
* Run the `Get process instance` request to load the `processInstanceId` parameter
* Run the `Get instance details` request to load the `taskInstanceId` parameter
* Finally, run the `Custom getTask` and `Custom skip` requests to load the metadata of the given task and to skip the execution

Once completed, go back to the `Process Diagram` tab and verify that the whole process has completed the execution.

# WIP switch off XA from MS SQL command line
** WIP **
Troubleshooting:

https://stackoverflow.com/questions/4043859/exception-with-ms-sql-server-jdbc-and-xa-transactions

```shell
oc run -it --rm mssql-tools --image mcr.microsoft.com/mssql-tools

/opt/mssql-tools/bin/sqlcmd -Usa -PmsSql2019 -S${MSSQL_SERVICE_SERVICE_HOST},${MSSQL_SERVICE_SERVICE_PORT} -Q \
"use [rhpam]
GO
EXEC sp_addrolemember [SqlJDBCXAUser], 'SA' 
GO"

/opt/mssql-tools/bin/sqlcmd -Usa -PmsSql2019 -S${MSSQL_SERVICE_SERVICE_HOST},${MSSQL_SERVICE_SERVICE_PORT} -Q \
"use [rhpam]
GO
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_commit] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_end] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_forget] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_forget_ex] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_init] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_init_ex] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_prepare] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_prepare_ex] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_recover] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_rollback] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_rollback_ex] TO [sa]
GRANT EXECUTE ON [dbo].[xp_sqljdbc_xa_start] TO [sa]"
```
