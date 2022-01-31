# Functional validation report for [dev-env]
**Miscellaneous issues**:
* ✅ [[Issue] Kie Server installer connects to controller using HTTP protocol](https://issues.redhat.com/browse/APPENG-250)

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
* ✅ [[Issue] Build & Install periodically fails](https://issues.redhat.com/browse/APPENG-220)

## Process management from Business Central
- [x] Start a process on KS
  - [X] Process is listed in `Process Instance` page
  - [X] Validate process state and diagram
- [x] Complete the process
  - [x] The process state is updated accordingly

Repeat the above tests for the following scenarios:
- [x] Process without human task that auto-completes
- [x] Process with human task
  - The user task is assigned to the user who deployed the project

**Issues**:
* ✅ [[Issue] Deployed process is not listed in Business Central console](https://issues.redhat.com/browse/APPENG-222)
* ✅ [[Issue] Human task not listed under Task Inbox page](https://issues.redhat.com/browse/APPENG-227)
* ✅ [[Issue] 2 browsers showing different redirect URIs for 'business-central' client](https://issues.redhat.com/browse/APPENG-226)
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
- [x] Configure remote repository
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
- [x] Admin>Roles page contains the roles defined in Keycloak `Rhpam` realm
- [x] Admin>Groups page contains `kie-server` role defined in Keycloak `Rhpam` realm
- [x] Admin>Users page contains the users defined in Keycloak `Rhpam` realm
- [x] Create a new user from Admin>Users page
  - [x] The user is reflected in the Keycloak `Rhpam` realm
- [x] Delete a user from Admin>Users page
  - [x] The user is removed from the Keycloak `Rhpam` realm

**Issues**:
* ✅ [[Issue] Admin page is not listing expected Roles, Groups and Users](https://issues.redhat.com/browse/APPENG-221)

## Testing Kie-Server REST API
- [x] Get list of available containers using `GET https://{{kieserver-url}}/services/rest/server/containers`
- [x] Deploy a new container using
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
  - [x] The list of available containers is updated
- [x] Undeploy a container using `DELETE {{scheme}}://{{kieserver-url}}/services/rest/server/containers/<NAME>` and payload:
  - [x] The list of available containers is updated
- [x] List processes for a given container using 
`GET {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/processes`
  - [x] The list returns the deployed processes
- [x] Start a process instance for a given container using: 
```shell
GET {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/processes/instances
GET {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/processes/instances/{{processInstanceId}}
POST {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/processes/{{processId}}/instances
```
  - [x] The list of active processes is updated
- [x] Complete an active process using one of:
```shell
PUT {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/tasks/{{taskInstanceId}}/states/started?user=rhpamadmin
PUT {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/tasks/{{taskInstanceId}}/states/completed?user=rhpamadmin
PUT {{scheme}}://{{kieserver-url}}/services/rest/server/containers/{{containerId}}/tasks/{{taskInstanceId}}/states/skipped?user=rhpamadmin
```
  - [x] The list of active processes is updated
  - [x] The process status is updated

Repeat the above tests for the following scenarios:
- [x] With a container actually deployed on Maven repository and/or on the server
- [x] With a container that is not deployed on Maven repository or on the server
  - A failure response is expected

**Issues**:
* ✅ [[Issue] Kie-Server APIs are not showing the active Human Tasks](https://issues.redhat.com/browse/APPENG-248)
* ✅ [[Issue] Cannot start task from REST API](https://issues.redhat.com/browse/APPENG-251)
* ✅ [[Issue] Swagger page not available](https://issues.redhat.com/browse/APPENG-252)
