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

##Procedure:

###Creating a customized image with jenkins and aws cli utility:

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

3. login to the registry
```shell
podman push docker.io/youruser/yourrepo:tag#
```

### Running Jenkins Instance on Openshift
1. Login to your oc cluster with your credentials.

2.Create a new project 
```shell
oc new-project your-project
```
####Jenkins Installation   
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
###TODO -complete runbook with relevant commands to interact with AWSCLI(including authorization and secret credentials in jenkins), github and KIEServer

<!-- links -->
[Helm Installation Page]: https://helm.sh/docs/intro/install/
[Podman Installation Page]: https://podman.io/getting-started/installation

