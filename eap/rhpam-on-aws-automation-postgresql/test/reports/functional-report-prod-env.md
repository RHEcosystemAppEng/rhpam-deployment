# Functional validation report for [prod-env]

## Testing Kie-Server REST API
- [x] Get list of available containers using `GET https://{{kieserver-url}}/services/rest/server/containers`
- [x] Deploy a new container
  - [x] An error is returned as the server in immutable: "KIE Server management api is disabled"
- [x] Undeploy a container
  - [x] An error is returned as the server in immutable: "KIE Server management api is disabled"
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
* ✅ [[Issue] Swagger page not available](https://issues.redhat.com/browse/APPENG-252)
