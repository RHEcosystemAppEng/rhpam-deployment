# Jenkins checklist
The purpose 

- [ ] Pipeline on Kie server without user data
  - [ ] User data is added/updated
    - [ ] new launch configuration is created with the latest user data
    - [ ] launch configuration is attached to ASG
  - [ ] Container is added
    - [ ] Visible in BC**
    - [ ] Available through Rest API from kie server
  - [ ] Process can be created and runs successfully

Repeat above check for pipeline run on kie server WITH existing user data

- [ ] Pipeline on Kie server WITH existing user data - additional checks to above
  - [ ] Old container removed from server