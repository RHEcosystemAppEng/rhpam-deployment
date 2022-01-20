# Jenkins checklist Testing Report
The purpose is to check that the 2 pipelines jobs - 'build-artifact' and 'deploy-artifact DEV' jobs are working together
in a chain in order to build a new or changed artifact in a source git repo(particularly external that is 
synced with business-central's internal git repo) and deploy it to managed kie servers.

  - [X] Run Pipeline 'build-artifact' triggered from sample git repo contains an App created in BC.
    - [X] Build maven artifact
    - [X] Deploy artifact to an external maven repository(repsy.io)configured in RHPAM 
    - [X] Trigger automatically job 'deploy-artifact' to run with GAV + awsRegion  as parameters 
   
 
  - [x] Run Pipeline job 'deploy-artifact' to deploy artifact on Kie servers - kie servers have 
        no Containers deployed
    - [x] User data is added/updated
      - [x] new launch configuration is created with the latest user data
      - [x] launch configuration is attached to ASG
    - [x] Container is added
      - [x] Visible in BC
      - [x] Available through Rest API from kie server
      - [x] Process can be created and runs successfully

  Repeat above check for pipeline run on kie servers WITH existing user data(Containing Containers)

-[x] run Pipeline job on Kie servers that contain containers  - additional checks to above:
  - [x] Old container removed from server(*1)


## Issues
- If a server is terminated NOT through the business central console, the server stays on in the 
Execution servers -> Server Configurations area. 
When then running a new process, getting popup error: `Unable to complete your request. The following exception occurred: No available endpoints found.`
The process is still executed successfully.
[[Issue] Terminated server not removed from BC](https://issues.redhat.com/browse/APPENG-280)
- (*1) A removed container stays on inside the Execution servers -> Deployment Units area.
This can cause an error message. Only reenter into the page removes it from the screen (refresh button on the screen does not).
