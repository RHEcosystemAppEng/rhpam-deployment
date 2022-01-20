# Jenkins checklist
The purpose is to check that the 2 pipelines jobs - 'build-artifact' and 'deploy-artifact DEV' jobs are working together
in a chain in order to build a new or changed artifact in a source git repo(particularly external that is
synced with business-central's internal git repo) and deploy it to managed kie servers.

- [ ] Run Pipeline 'build-artifact' triggered from sample git repo contains an App created in BC.
  - [ ] Build maven artifact
  - [ ] Deploy artifact to an external maven repository(repsy.io)configured in RHPAM
  - [ ] Trigger automatically job 'deploy-artifact' to run with GAV + awsRegion  as parameters


- [ ] Run Pipeline job 'deploy-artifact' to deploy artifact on Kie servers - kie servers have
  no Containers deployed
  - [ ] User data is added/updated
    - [ ] new launch configuration is created with the latest user data
    - [ ] launch configuration is attached to ASG
  - [ ] Container is added
    - [ ] Visible in BC**
    - [ ] Available through Rest API from kie server
  - [ ] Process can be created and runs successfully

Repeat above check for pipeline run on kie server WITH existing user data

- [ ] Run Pipeline job on Kie servers that contain containers  - additional checks to above:
  - [ ] Old container removed from server