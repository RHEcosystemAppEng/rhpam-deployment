# Configuring the production pipeline in Jenkins server
## Prerequisites
* Create `Credentials>Secret File` with ID `KEY_PAIR_PEM` and add the content of the pem file from the `Browse` button
* Create `Credentials>Username and password` with ID `RHPAM_ADMIN_CREDENTIALS` and configure username and password of an 
admin user (used to deploy the container artifacts from Jenkins to the server)
* Include path to AWS CLI v2 to `PATH` variable under `Manage Jenkins>Configure System>Global environment`
* **Also consider all the installation and configuration options defined in [README.md](./README.md)**  

## Setting the AWS Policy
The Jenkins EC2 instance must be assigned to a policy which allows the following actions:
```json
{
  "Effect": "Allow",
  "Resource": "*",
  "Action": [
    "ec2:CreateTags",
    "ec2:RunInstances",
    "ec2:CreateImage",
    "ec2:TerminateInstances",
    "autoscaling:CreateLaunchConfiguration",
    "autoscaling:CreateAutoScalingGroup",
    "autoscaling:AttachLoadBalancers",
    "autoscaling:AttachLoadBalancerTargetGroups",
    "autoscaling:DeleteLaunchConfiguration",
    "autoscaling:DeleteAutoScalingGroup",
    "elasticloadbalancing:CreateTargetGroup",
    "elasticloadbalancing:CreateLoadBalancer",
    "elasticloadbalancing:CreateListener",
    "elasticloadbalancing:ModifyListener",
    "elasticloadbalancing:DeleteTargetGroup",
    "tag:GetResources",
    "iam:PassRole"
  ]
}
```

## Loading the Jenkins job
Edit the given job configuration [prod-conf.xml](./prod-conf.xml), in particular providing a default value for 
the following job parameters:

| Paramater | Description|
|------|-----|
| `AWS_REGION` | The AWS region to deploy the immutable environment|
| `SECURITY_GROUP_ID` | ID of AWS security group to create:</br>- The template EC2 instance</br>- The launch configuration</br>- The application load balancer|
| `KEY_PAIR_NAME` | Name of the AWS Key pair to create:</br>- The template EC2 instance</br>- The launch configuration|
| `VPC_ID` | The ID of the VPC where the deployment runs|
| `VM_SUBNET_ID1` | ID of the AWS subnet to create:</br>- The template EC2 instance</br>- The auto scaling group|
| `VM_SUBNET_ID2` | ID of the secondary AWS subnet to create:</br>- The auto scaling group|
| `LB_SUBNET_ID1` | ID of the secondary AWS subnet to create the application load balancer|
| `LB_SUBNET_ID2` | ID of the secondary AWS subnet to create the application load balancer|
| `DEPLOYMENT_GROUP_ID` | The Maven groupId of the deployed artifact|
| `DEPLOYMENT_ARTIFACT_ID` | The Maven artifactId of the deployed artifact|
| `DEPLOYMENT_VERSION` | The Maven version of the deployed artifact|

Download `jenkins.jar` from `Manage Jenkins>Jenkins CLI` page, then run one of the following commands to create or update the 
Jenkins job called `deploy-immutable-artifact`:

```shell
java -jar jenkins-cli.jar -auth JENSKINS_USERNAME:JENSKINS_PASSWORD -s JENKINS_URL -webSocket create-job deploy-immutable-artifact < prod-conf.xml
java -jar jenkins-cli.jar -auth JENSKINS_USERNAME:JENSKINS_PASSWORD -s JENKINS_URL -webSocket update-job deploy-immutable-artifact < prod-conf.xml
```

## Running the pipelins
* Using `Dashboard>deploy-immutable-artifact>Build with Parameters` from Jenkins console
* Using the webhook trigger defined in the [pre-push hook](../demo-prod-env/README.md#configure-pre-push-hook)
of the production demo

**Note**: the average execution time of a single job is around 10-12 minutes, and is affected by:
* The number of VM instances to start (`ASG_DESIRED_CAPACITY` job parameter)
* Whether the application load balancer exists or has to be created
 

