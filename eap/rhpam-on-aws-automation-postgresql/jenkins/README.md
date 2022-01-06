# Provisioning Of a Jenkins Server on Openshift

  
Goal - To create a jenkins Automation server to run on Openshift cluster in order to intract with AWS API and Kie Servers for  deploying artifacts to Kie Servers.
* The Idea is to use bitnami jenkins chart with modified customized image that will
  contain all of the content of the parent image, and in addition will include AWS cli utility to interact
 with AWS console API using its CLI.
* Create the modified desired image and Push it to your repository in containers registry. 

* After having the custom image,  override image name and version of chart to your custom name and version, in addition to a few more values
  in chart.      

* This chart installation supplies admin username and password determined and controlled by the values injected to
  chart when installing jenkins using Helm

 

  
## Prerequisites 

* Helm Package manager version 3 or higher
 , it can be download via the following link:
[Helm installation link][Helm Installation Page]

* Podman CLI - A Lightweight tool for running and manipulating linux containers - can be 
 downloaded from the following link:
[Podman Installation link][Podman Installation Page]
* An account at a containers registry service like quay.io or docker.io

* A Running Openshift Cluster

## Procedure:

### Creating a customized image with jenkins and aws cli utility:

**Create a new image from jenkins bitnami newest image version**

1. Create a Containerfile/Dockerfile with the following content:

```dockerfile
FROM docker.io/bitnami/jenkins:latest

USER root

RUN apt-get update && apt-get install -y less groff awscli

USER jenkins

ENTRYPOINT ["/opt/bitnami/scripts/jenkins/entrypoint.sh"]

CMD ["/opt/bitnami/scripts/jenkins/run.sh"]
```

2. inside the directory of the DockerFile/Containerfile, run(could be any public external registry you have an account in, in this example it's docker.io):
```shell
podman build . -t docker.io/youruser/yourrepo:tag#
```

3. login to the registry using your credentials:
 ```shell
 podman login -u username -p password docker.io
 ```

4. Push the image to your registry:
```shell
podman push docker.io/youruser/yourrepo:tag#
```

### Running Jenkins Instance on Openshift
1. Login to your oc cluster with your credentials.

2.Create a new project (for example your-project=jenkins-test)
```shell
oc new-project your-project
```
#### Jenkins Installation   
3.now We'll use the self created container image from previous step in order to run on cluster Jenkins with AWS cli utility(if wanted to use another registry than docker.io, need to override in values.yaml property volumePermissions.image.registry),notice that JenkinsUser & JenkinsPassword are the credentials of admin user of jenkins:
```shell
helm install jenkins-test  --set jenkinsUser=admin   --set jenkinsPassword=******* \
--set image.repository=youruser/yourrepo --set image.tag=tag# \
--set service.type=ClusterIP --set persistence.size=4Gi \   
--set podSecurityContext.enabled=false \ 
--set containerSecurityContext.enabled=false  bitnami/jenkins 
```
**Note: If the registry is not docker.io, you can override docker.io by supplying other registry like quay.io in parameter volumePermissions.image.registry(e.g ,add to the above command --set volumePermissions.image.registry=quay.io)**

4. Wait for jenkins server to be up and ready

```shell
[zgrinber@zgrinber tmp]$ oc get pods
NAME                            READY   STATUS    RESTARTS   AGE
jenkins-test-587fbcf497-76knq   1/1     Running   0          120s
```

5.expose the service with a Route so it will be able to be accessed from outside the cluster:
```shell
[zgrinber@zgrinber tmp]$ oc expose svc jenkins-test
```
6.Get the route Url and enter it in a web browser, use the user admin credentials determined back in section 3. 
```shell
zgrinber@zgrinber tmp]$ oc get route | awk '!/^(NAME)/' | awk '{print $2}'
jenkins-test-zgrinber-dev.apps.sandbox.x8i5.p1.openshiftapps.com
```
## Jenkins Configuration

### Global Configuration
FIrst, Go to global configuration Inside Jenkins Main screen(Dashboard)-> Go to *Manage Jenkins* on the left panel-> Click on *Configure System*
- **_Define a HOME environment variable for jenkins:_**


   search for `Global properties` header and check a checkbox named "Environment variables"
   , Click the 'add' Button and then fill in the following values in the new fields:
```properties
Name=HOME 
Value= /bitnami/jenkins/home
```
- **_Define a shared library for usage in pipelines_**: 
  
    Search for `Global Pipeline Libraries` Header and click on the 'Add' button.
    a group of fields revealed , populate the fields with following values

#### Text Values:
```prototext 
Name=shared-jenkins-library,
Default Version= main,
Retrieval method= Modern SCM,
Source Code Management=https://github.com/RHEcosystemAppEng/rhpam-deployment.git 


```

#### CheckBox Values:
- [ ] Load implicitly
- [X] Allow default version to be overridden
- [X] Include @Library changes in job recent changes


### Install Plugins:

#### The following plugins are required in order to run the pipelines(some of them already installed):
   
   - Config File Provider Plugin
   - Credentials Binding Plugin
   - Credentials Plugin
   - git plugin
   - Kubernetes(Optional - If wanted to use to run slaves using pod templates)
   - Maven Integration(Optional)
   - Pipeline: Groovy
   - Pipeline: Shared Groovy Libraries
   - Pipeline: SCM Step
   - SCM API Plugin
   - Workspace Cleanup
   - Pipeline Utility Steps
   - Blue Ocean
   - Configuration As Code Plugin(Optional)

#### How to Install Plugins:
in main menu of Jenkins server, go to Manage Jenkins->Click on Manage Plugins->
THen Go to 'Available' tab->in the above search editor field enter the required plugin or look for it
In the presented table of available plugins, next to the desired plugins(can check multiple plugins), check their checkbox
and click below on either of buttons 'Install without Restart' and then click on checkbox 'restart jenkins', as shown in the following pictures

![Example of installing plugin](./pictures/pluginInstallation.png)
![Example of installing plugin](./pictures/pluginInstallation2.png)

### Credentials and Secrets management:
Jenkins manage and store the credentials in a secured manner and in a secured place, 
and using the 'Credentials Binding Plugin' it can inject any credentials into a pipeline in order to be used,
jenkins and the plugin masking the secrets from being displayed on logs, so they remain secured 
and there is no fear that secrets will be leaked or compromised 
#### The following credentials should be defined in Jenkins(their **_ids_** are listed):
- maven-repo-secret - username and password for maven repository in a remote server
- AWS_CREDENTIALS - AWS Access Key Id and Secret for AWS cli login, should be defined as user and password kind. 
- KS_CREDENTIALS - Kie Server Controller Username and password for interacting with Kie Server using REST API
- jenkins-sa-token(optional) - In case of using kubernetes pod template as jenkins agent/slave - should be defined with kind of Secret text.

#### How to define credentials in jenkins:
From jenkins server main screen, go to Manage Jenkins-> go to security section-> click on Manage Credentials
-> then on the bottom click on '(global)' link under Domains column->on the left panel click on 'Add Credentials'
Then you should fill the details of secret as shown below:

**_username and password kind of secret:_**

![define credential](./pictures/addnewsecret.png)

**_secret text kind:_**

![define credential](./pictures/addnewsecret2.png)

### Defining external configuration file(Example with maven - settings.xml)
Jenkins, Using 'Config File Provider Plugin', offers a way to decouple config files
From the jenkins agent that the pipeline will run onto, so the configuration file is defined as an object with id, and it can be used through pipeline execution using the plugin,
regardless of the agent that is being used, jenkins inject/mount the rendered file
config file into agent's workspace(file system) only when needed, and there it can be used as file transparently.

From jenkins server main screen, go to Manage Jenkins->at System Configuration-> click on Managed files-> on left panel click on 'Add a new Config' 
, choose Global Maven settings.xml, and then click on the Add button to add ServerId and credentials for authentication to it, for example

![sample](./pictures/configfilemavensettingsxml.png)

_**where the given settings.xml for this is as follows:**_
```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
    <profiles>
        <profile>
            <id>rhpam</id>
            <activation>
                <activeByDefault>true</activeByDefault>
            </activation>
            <repositories>
                <repository>
                    <id>redhat-ga</id>
                    <url>https://maven.repository.redhat.com/ga/</url>
                </repository>
            </repositories>
            <pluginRepositories>
                <pluginRepository>
                    <id>redhat-ga</id>
                    <url>https://maven.repository.redhat.com/ga/</url>
                </pluginRepository>
            </pluginRepositories>
            <distributionManagement>
                <repository>
                    <id>rhpam</id>
                    <url>https://repo.repsy.io/mvn/dmartino/rhpam</url>
                </repository>
            </distributionManagement>
        </profile>
    </profiles>
</settings>
```
**_Note: Need to specify in ServerId the desired id of server (to deploy artifacts)
in settings.xml and choose jenkins credentials for the maven repo 
and then the plugin will inject the user/password to the rendered
settings.xml that will be injected to running agent during runtime_**

### Setup A Kubernetes pod template agent

Jenkins jobs can run on master node(jenkins master), but it's not considered
as best practice because of the following reasons:

- running pipelines on master can rise security issues as the build information
  and data, as well as some of the configuration can be accessed during the run in case the jenkins master 
  is breached , and if the pipeline code doesn't take care explicitly of cleaning the workspace at the
  end of the run, then the data of the build persisted on master's file system itself until
  initiative clean-up/house-keeping procedure take place, which is very bad.


- from performance point of view, running all pipelines jobs on master node can lead
  to poor performance, as jenkins in this case has to run itself all pipelines, allocate a thread
  to each running build, and in addition to that, it already has managing tasks of its own , and it needs to listening to new incoming jobs, and etc. 

**_Note: there is no obligation to use kubernetes pod templates for jenkins agents,
   it's just one option among others, below several of them:_**
- running jenkins agents from docker images, and connecting to container using SSH.
- running jenkins agents on aws EC2 instances using a designated plugin.
- running jenkins agents on bare metal machines that is accessible to jenkins master 
  via some network
- running jenkins agents from pod template in k8s/openshift clusters.
- and several more...

**_We'll go through the setup and configuration required to setup pod templates
agents in jenkins that will run in an openshift cluster._**

#### First Step: Create Service Account in openshift Cluster

1. login to openshift cluster using oc login.
2. switch to project/namespace that you want projects to run in, for example,
   if wants to run in the same project where jenkins master is running, type:
```shell
oc project jenkins-test
```
3. Create a service account for jenkins that it be able to access cluster:
```shell
oc create serviceaccount jenkins -n jenkins-test
```
4.Create a Role object to define the authorized access actions and objects
```shell
cat > jenkins-role.yaml << EOF
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: jenkins
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create","delete","get","list","patch","update","watch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create","delete","get","list","patch","update","watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get","list","watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
EOF

```
```shell
oc apply -f jenkins-role.yaml -n jenkins-test
```
5.Create a Role-binding to bind the created Role to our ServiceAccount:
```shell
cat > jenkins-rolebinding.yaml << EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jenkins
  namespace: jenkins-test
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: jenkins
subjects:
- kind: ServiceAccount
  name: jenkins
EOF
```
```shell
oc apply -f jenkins-rolebinding.yaml -n jenkins-test
```
6. get the secret token of the service account in clusterto be later defined 
   in jenkins as credential:
```shell
oc get secret $(oc get sa jenkins -n jenkins-test -o jsonpath={.secrets[0].name}) -n jenkins-test -o jsonpath={.data.token} | base64 --decode
```

7.get the certificate authority ca.crt file secret of serviceAccount in openshift cluster
  to be later defined as 'Kubernetes server certificate key' field in configure cloud when defining openshift cloud at jenkins:  
```shell
oc get secret $(oc get sa jenkins -n jenkins-test -o jsonpath={.secrets[0].name}) -n jenkins-test -o jsonpath={.data.'ca\.crt'} | base64 --decode
```
<!-- links -->
[Helm Installation Page]: https://helm.sh/docs/intro/install/
[Podman Installation Page]: https://podman.io/getting-started/installation

8.If running on the same namespace as jenkins master, you can apply this service account to jenkins deployment:
```shell
oc patch deployment/jenkins-test -p '{"spec":{"template":{"spec":{"serviceAccount":"jenkins"}}}}'
```

#### Second Step: Define Openshift Cloud in jenkins
1. in main menu of Jenkins server, go to Manage Jenkins->In System configuration Section
   go to 'Manage Nodes And Clouds'->Go on the left panel to Configure Clouds->
   press on button/drop down list 'Add a new cloud', and choose Kubernetes.
2. In Name field call it Openshift, and click on Kubernetes Cloud Details.
3. A new screen appeared with several fields, beside name that already entered
   fill in the following details:
```prototext
Kubernetes URL = the url of openshift API server, 
for example - https://api.ocp-dev01.lab.eng.tlv2.redhat.com:6443

Kubernetes server certificate key - paste here the value from former step section 7

Kubernetes Namespace= namespace/project where pod agents will run - 
for example in our case - jenkins-test
    
Credentials= click on add button-> you will navigated to add new secret, choose kind
of secret text,in secret field paste in the value from section 6 from former step.
give id and description and after adding it, choose it as the credentials.

jenkins URL = the url of jenkins master for agents to log into it- if jenkins
running in the cluster then need to give the service dns name of jenkins in
 openshift cluster or cluster ip of svc or ip of pod 
that running Jenkins, with port 8080.
for example : http://jenkins-test.jenkins-test.svc.cluster.local:8080

Pod label:
key=jenkins,
Value=agent
The remaining fields can stay with default values.
```
4. After filling all above fields, click on button "Pod Template Details..."
   and then click on Add Pod Template, and you should supply image for the pod
   that will run when the pod agent will be created by jenkins, see example 
   in the screenshots below:
![sample](./pictures/openshiftcloud1.png)
![sample](./pictures/openshiftcloud2.png)
![sample](./pictures/openshiftcloud3.png)
![sample](./pictures/openshiftcloud4.png)

**_Explanation for important fields in the screenshot:_**
```properties
Name = the Pod template name,
Namespace = in which namespace in the cluster the agent pod will run
Labels = the name of the agent pod in order to instruct jenkins to run a pipeline code on it 
ContainerName = the name of the container of the agent in pod
DockerImage = the Docker image that the container will be derived from - must be sub image of jenkins/agent or jenkins/slave
WorkingDirectory = the directory in which the agent will work in when provisioned for a pipeline
PersistentVolumeClain = a name of PVC that can be mounted into mount path in container in order to increase performance of build, for example, for a maven builder agent, it's sensible to mount a pvc to the agent's local repository directory, so it will not need to download the artifacts over and over on each build, just refresh whatever is new or deleted.              
```
5.Click on Save.

6.Go to Manage Jenkins->Security section->click on Configure Global Security->
   in Agents Section, choose radioButton Random,
   And in 'Agent - Controller Security', check checkbox 'Enable Agent -> Controller Access Control'
