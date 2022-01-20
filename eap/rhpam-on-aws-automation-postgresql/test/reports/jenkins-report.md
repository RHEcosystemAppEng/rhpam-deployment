# Jenkins checklist
The purpose ...

- [x] Pipeline on Kie server without user data
  - [x] User data is added/updated
    - [x] new launch configuration is created with the latest user data
    - [x] launch configuration is attached to ASG
  - [x] Container is added
    - [x] Visible in BC
    - [x] Available through Rest API from kie server
  - [x] Process can be created and runs successfully

Repeat above check for pipeline run on kie server WITH existing user data

- [x] Pipeline on Kie server WITH existing user data - additional checks to above
  - [x] Old container removed from server(*1)


## Issues
- If a server is terminated NOT through the business central console, the server stays on in the 
Execution servers -> Server Configurations area. 
When then running a new process, getting popup error: `Unable to complete your request. The following exception occurred: No available endpoints found.`
The process is still executed successfully.
[[Issue] Terminated server not removed from BC](https://issues.redhat.com/browse/APPENG-280)
- (*1) A removed container stays on inside the Execution servers -> Deployment Units area.
This can cause an error message. Only reenter into the page removes it from the screen (refresh button on the screen does not).
