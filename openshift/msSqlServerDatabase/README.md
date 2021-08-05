# Table of Contents
* [Deploy RHPAM on OpenShift with MS SQL Server](#deploy-rhpam-on-openshift-with-ms-sql-server)
  * [Deploy MS SQL instance](#deploy-ms-sql-instance)
    * [Create the RHPAM database and validate the MS SQL installation](#create-the-rhpam-database-and-validate-the-ms-sql-installation)
 * [Build and push the custom KIE Server image](#build-and-push-the-custom-kie-server-image)
 * [Deploy the RHPAM application](#deploy-the-rhpam-application)
   * [Validate the installation](#validate-the-installation)

# Deploy RHPAM on OpenShift with MS SQL Server
## Deploy MS SQL instance
**Note**: These steps are optional if you already have your own running instance of MS SQL server (either as an OpenShift 
container or as a standalone service)
**Note**: These steps deploy an instance of MS SQL 2019 in the same OCP project where RHPAM will be then installed
**Note**: The original instructions are available at [Workshop: SQL Server 2019 on OpenShift (CTP 2.5)](https://github.com/johwes/sqlworkshops-sqlonopenshift/tree/master/sqlonopenshift/01_deploy).
The repository was forked to add a fix for latest versions of OpenShift.

**Prerequisites**
* You are logged into the OpenShift project

Create the password secret and deploy MS SQL instance
```shell
git clone git@github.com:dmartinol/sqlworkshops-sqlonopenshift.git
cd sqlworkshops-sqlonopenshift/sqlonopenshift/01_deploy
oc create secret generic mssql --from-literal=SA_PASSWORD="msSql2019"
oc apply -f storage.yaml
oc apply -f sqldeployment.yaml
```

In case you consider changing the password, please consider the password policy requirements: 
`The password must be at least 8 characters long and contain characters from three of 
the following four sets: Uppercase letters, Lowercase letters, Base 10 digits, and Symbols`

### Create the RHPAM database and validate the MS SQL installation
* Install [Azure Data Studio](https://github.com/Microsoft/azuredatastudio)
* Forward the MS SQL port to the localhost with:
  ``oc port-forward `oc get pods -o custom-columns=POD:.metadata.name --no-headers | grep mssql-deployment` 1433:1433``
* Connect the `Azure Data Studio` using server `localhost`, user `sa` user and password `msSql2019` 
* Once connected, run the following SQL commands to check the database version and create the `rhpam` database:
```roomsql
SELECT @@version;
CREATE DATABASE rhpam;
SELECT name FROM master.sys.databases;
USE rhpam;
SELECT * FROM information_schema.tables;
```
* Select the `master` DB then create the RHPAM user `rhpam/rhPam123` with:
```roomsql
CREATE LOGIN [rhpam] WITH PASSWORD = 'rhPam123';
CREATE USER [rhpam] FROM LOGIN [rhpam] WITH DEFAULT_SCHEMA=rhpam;
ALTER ROLE db_owner ADD MEMBER [rhpam];
```
* Finally, to fix the issue with the distributed transactions mentioned [here](https://access.redhat.com/solutions/4926011),
execute the following commands:
```roomsql
EXEC sp_sqljdbc_xa_install;
-- EXEC sp_grantdbaccess 'rhpam', 'rhpam'
EXEC sp_addrolemember [SqlJDBCXAUser], 'rhpam'
```

## Build and push the custom KIE Server image
The following steps generate a custom KIE Server image with the following features:
* Base image is 7.9.0
* Integrates the `custom-endpoints` artifact generated from the [custom-endpoints](../immutableImage/custom-endpoints) project
* Integrates the MS SQL driver with no need of an additional xtension image

The following commands generate the image with Podman, using the Vagrant configuration file [Vagrantfile](./Vagrantfile)provided as a reference.
They also push the image on the [Quay repository](https://quay.io/repository/ecosystem-appeng/rhpam-kieserver-rhel8-custom-mssql?tab=tags)
of the AppEng group:
```shell
./setup.sh
vagrant up
podman system connection add fedora33 ssh://vagrant@127.0.0.1:2222
podman build -t quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom-mssql:7.9.0 .
podman push quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom-mssql:7.9.0
```

## Deploy the RHPAM application
[custom-rhpam-mssql.template](./custom-rhpam-mssql.template) defines the `KieApp` instance for the RHPAM application, with the 
following features:
* KIE Server:
  * Custom image `rhpam-kieserver-rhel8-custom-mssql`  with extension API and MS SQL driver
  * 1 replica
* Business Central:
  * 1 replica

You can use this file as a reference to configure your instance. In particular, if you use your own DB instance, look at 
properties in the `database.externalConfig` section, to connect it to your exact MS SQL instance.
**Note**: if you pushed the custom image on a different repository or with a different name, you might updated the
`image`, `imageContext` and `imageTag` properties to match your actual configuration.

Before deploying the application we must provide the secret to login to Quay, as described [here](../deployCustomJarOnOCP/README.md#authenticate-the-quayio-registry):
```shell
oc create -f quay.io-secret.yaml
QUAYIO_SECRET_NAME=$(grep name quay.io-secret.yaml | sed -e 's/.*: //')
oc secrets link default ${QUAYIO_SECRET_NAME} --for=pull
oc secrets link builder ${QUAYIO_SECRET_NAME} --for=pull
```

If you are using the MS SQL instance described above, we need to generate the actual YAML configuration starting from the 
reference [custom-rhpam-mssql.template](./custom-rhpam-mssql.template) template. 
The following command sets the actual URL connection of the MS SQL deployment:
```shell
sed "s/MSSQL_URL/`oc get svc mssql-service -o jsonpath="{..spec.clusterIP}:{..spec.ports[0].port}"`/g" custom-rhpam-mssql.template > custom-rhpam-mssql.yaml
```
Finally, we can deploy the sample application with:
```shell
oc create -f custom-rhpam-mssql.yaml
```

**Note**: since we are pushing the container images into the OCP namespace, there's no need to define the secrets to store
the login passwords to `Quay.io` nor to the `Red Hat registry'

### Validate the installation
1. Verify the custom library is installed properly:
```shell
oc exec `oc get pods | grep kieserver-custom-mssql | grep Running | awk '{print $1}'` \
  -- ls /opt/eap/standalone/deployments/ROOT.war/WEB-INF/lib/custom-endpoints-1.0.0-SNAPSHOT.jar
oc exec `oc get pods | grep kieserver-custom-mssql | grep Running | awk '{print $1}'` \
  -- find /opt/eap/modules/com
```
2. Run the application from the `Route` called `custom-rhpam-mssql-rhpamcentrmon`
