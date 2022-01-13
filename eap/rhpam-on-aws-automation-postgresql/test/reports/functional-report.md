# Functional checklist

## RHPAM Authoring with local git
- [x] Create project on BC
  - Add `<distributionManagement>` to `pom.xml` pointing to Maven repository
- [x] Deploy project on the server
  - [x] Running server is listed in `Execution Servers` page
  - [x] Artifact is deployed on Maven Nexus repository
  - [x] Artifact is deployed on server
  - [x] Business processes are listed under `Process Definitions` page

**Issues**:
* ✅ [[Issue] Server not listed in ExecutionServers page](https://issues.redhat.com/browse/APPENG-219)
* 🚧 [[Issue] Build & Install periodically fails](https://issues.redhat.com/browse/APPENG-220)

## Process management from Business Central
- [ ] Start a process on KS
  - [X] Process is listed in `Process Instance` page
  - [X] Validate process state and diagram
- ❌ Complete the process
  - ❌ The process state is updated accordingly

Repeat the above tests for the following scenarios:
- [X] Process without human task that auto-completes
- ❌ Process with human task
  - The user task is assigned to the user who deployed the project

**Issues**:
* ✅ [[Issue] Deployed process is not listed in Business Central console](https://issues.redhat.com/browse/APPENG-222)
* 🚧 [[Issue] Human task not listed under Task Inbox page](https://issues.redhat.com/browse/APPENG-227)
* 🚧 [[Issue] 2 browsers showing different redirect URIs for 'business-central' client](https://issues.redhat.com/browse/APPENG-226)
## RHPAM Authoring with remote git
The purpose is to connect the Business Central Git to the remote Git
so that all changes are sync-ed between the two repositories.

### Preliminary steps
- [x] Create an empty project in BC
- [x] Clone the project locally
  - Use project settings to define the local Git URL
  - Clone using HTTPS protocol and the `rhpamAdmin` user
- [x] Push project on git server
  - [x] Create the empty project on git server
    - Remember to `sudo su` and `su - git`
  - [x] Update the remote origin to use the git server's URL
```shell
git remote set-url origin <REMOTE_URL> 
```
- [x] Push the changes
```shell
git push -u origin master
```
- [ ] Configure remote repository
  - [x] Delete project from Business central
  - [x] Import project from remote git repository
  - [x] Configure post-commit hook in `_EFS_MOUNT_POINT_/.niogit/<SPACE>/<PROJECT_NAME>.git/hooks`
```shell
echo '#!/bin/sh
git push origin +master' > post-commit
chmod 744 post-commit
```

**Issues**:
* ✅ [[Issue] Cannot import project from Git server](https://issues.redhat.com/browse/APPENG-230)

### Authoring tests
- [x] Clone the project from the remote git under `/tmp`
- [x] Apply changes to the project
  - [x] Pull changes on the local repository in `/tmp`
  - [x] Validate the changes are present

## User Management from Business Central
- ❌ Admin>Roles page contains the roles defined in Keycloak `Rhpam` realm
- [ ] Admin>Groups page contains `kie-server` role defined in Keycloak `Rhpam` realm
- [ ] Admin>Users page contains the users defined in Keycloak `Rhpam` realm
- [ ] Create a new user from Admin>Users page
  - [ ] The user is reflected in the Keycloak `Rhpam` realm
- [ ] Delete a user from Admin>Users page
  - [ ] The user is removed from the Keycloak `Rhpam` realm

**Issues**:
* 🚧 [[Issue] Admin page is not listing expected Roles, Groups and Users](https://issues.redhat.com/browse/APPENG-221)

## Testing Kie-Server REST API
- [ ] Get list of available containers using `GET https://{{kieserver-url}}/services/rest/server/containers`
- [ ] Deploy a new container using
`PUT {{scheme}}://{{kieserver-url}}/services/rest/server/containers/<NAME>` and payload:
```json
{
    "container-id" : "<NAME>",
    "release-id" : {
        "group-id" : "<GROUP ID>",
        "artifact-id" : "<ARTIFACT ID>",
        "version" : "<VERSION>"
    }
}
```
- [ ] The list of available containers is updated
- [ ] Undeploy a container using `DELETE {{scheme}}://{{kieserver-url}}/services/rest/server/containers/<NAME>` and payload:
  - [ ] The list of available containers is updated
- [ ] List processes for a given container using 
`GET {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/processes`
  - [ ] The list returns the active processes
- [ ] Start a process instance for a given container using 
`POST {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/processes/{{processId}}/instances`
  - [ ] The list of active processes is updated
- [ ] Complete an active process using
`PUT {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/tasks/{{taskInstanceId}}/states/skipped`
    - [ ] The list of active processes is updated
    - [ ] The process status is updated

Repeat the above tests for the following scenarios:
- [ ] With a container actually deployed on Maven repository and/or on the server
- [ ] With a container that is not deployed on Maven repository or on the server
  - A failure response is expected
