# Table Of Contents
* [Custom Queries](#custom-queries)
  * [Custom Task Query](#custom-task-query)
  * [Track changes of requestId variable](#track-changes-of-requestid-variable)
  * [Sequence diagrams](./SequenceDiagrams.md)

# Custom Queries
## Custom Task Query
The request is to register a query that:
* Returns details on the Tasks, including:
  * Some well-identified Task and Process variables (see next)
  * Actual and potential owners
  * Status
* Allows fully configurable filter using the usual SQL operators and with possibility to generate conditional
expressions with nested conditional groups concatenated by AND or OR operators
* Returns paginated result
* Supports sorting on one of the exposed columns

To simplify the registration of the custom query, we provide a reference SQL script [view.sql](./view.sql) to define a 
`CustomView` DB view that exposes all the requested columns:

| Column | Origination table |
|---|---|
| TASKID | TASK.ID |
| DESCRIPTION | TASK.DESCRIPTION |
|TASKTYPE | TASKTYPE.VALUE |
|REQUESTID | TASKVARIABLEIMPL.VALUE WHERE TASKVARIABLEIMPL.NAME LIKE 'requestId' |
|FACILITYID | TASKVARIABLEIMPL.VALUE WHERE TASKVARIABLEIMPL.NAME LIKE 'facilityId' |
|PARTYID | TASKVARIABLEIMPL.VALUE WHERE TASKVARIABLEIMPL.NAME LIKE 'partyId' |
|STAGE | (LATEST) VARIABLEINSTANCELOG.VALUE WHERE VARIABLEINSTANCELOG.VARIABLEID LIKE 'stage' |
|OVERVIEW | TASKVARIABLEIMPL.VALUE WHERE TASKVARIABLEIMPL.NAME LIKE 'overview' |
|COUNTER | (LATEST) VARIABLEINSTANCELOG.VALUE WHERE VARIABLEINSTANCELOG.VARIABLEID LIKE 'counter' |
|DUEDATE | AUDITTASKIMPL.DUEDATE |
|LASTMODIFICATIONDATE | AUDITTASKIMPL.LASTMODIFICATIONDATE|
|STATUS| TASK.STATUS|
|ACTUALOWNER | TASK.ACTUALOWNER_ID|
| POTENTIALOWNERS | PEOPLEASSIGNMENTS_POTOWNERS.ENTITY_ID (CONCATENATED BY ',')|

The attached [Postman collection](./Temenos-CustomView.postman_collection.json) defines sample REST requests to:
* Register the custom query: `Register queryOnCustomView` request
* Execute one filtered query for a given USERID, ordered by descending time: `Run queryOnCustomView` request

The execution returns an array of array like the following, where the N-th value corresponds to the value of the N-th
column in the SELECT statement (see previous table):
```json
[ [ 27.0, "Another human description", null, "2", "2", "2", "2", "2", 
  null, 1632837600000, 1632147003000, "Ready", null, "group1_2, group1_3, rhpamAdmin" ] ]
```
**Note**: at the moment no custom mapper is available to map the response in a detailed JSON object, so the 
evaluation of the output must follow the ordinal position of the values in the arrays

The following is an example of filter specification that applies the SQL condition : 
`WHERE requestId IN ('R1', 'R2') AND (facilityId IN ('F1', 'F2') OR partyId in ('P1', 'P2'))`

```json
{
  "order-by": "lastModificationDate",
  "order-asc": false,
  "query-params": [
    {
      "cond-operator": "AND",
      "cond-values": [
        {
          "cond-column": "requestId",
          "cond-operator": "IN",
          "cond-values": [
            "R1",
            "R2"
          ]
        },
        {
          "cond-operator": "OR",
          "cond-values": [
            {
              "cond-column": "requestId",
              "cond-operator": "IN",
              "cond-values": [
                "R1",
                "R2"
              ]
            },
            {
              "cond-column": "facilityId",
              "cond-operator": "IN",
              "cond-values": [
                "F1",
                "F2"
              ]
            },
            {
              "cond-column": "partyId",
              "cond-operator": "IN",
              "cond-values": [
                "P1",
                "P2"
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

The list of supported SQL operators is defined in [CoreFunctionType](https://github.com/kiegroup/kie-soup/blob/e5c909959888ac498782b447851a824291319cdc/kie-soup-dataset/kie-soup-dataset-api/src/main/java/org/dashbuilder/dataset/filter/CoreFunctionType.java),
while the list of supported logical operator is in [LogicalExprType](https://github.com/kiegroup/kie-soup/blob/e5c909959888ac498782b447851a824291319cdc/kie-soup-dataset/kie-soup-dataset-api/src/main/java/org/dashbuilder/dataset/filter/LogicalExprType.java)

**Note**: the original request from which we derived the definition of the DB View is the following:
```text
Filteration:
requestId  - task meta data
facilityId - task meta data
partyId - task meta data
stage - process meta data
overview - task meta data(will be newly added)
dueDate - task meta data(will be newly added)
status - task status
taskType - task meta data
count  - process meta data
actual-owner  - task data
potential-owners  - task data
 
Sorting:
lastUpdatedDateTime - task meta data(will be newly added).
```
# Track changes of requestId variable
Request is to export the list of the latest events by user for a given variable `requestId`.
The associated query is as follows:
```sql
SELECT te.TASKID ,te.id,te.LOGTIME ,te.TYPE ,ti.VALUE,te.USERID 
    FROM TASKVARIABLEIMPL ti inner join TASKEVENT  te on te.TASKID =ti.TASKID  
    where  ti.NAME ='requestId' and te.TYPE  in('ACTIVATED','STARTED','COMPLETED','ABORTED')
```

We provide a [Postman collection](./Temenos-Events.postman_collection.json) with all the required requests to:
* Register the custom query: `Register filteredTaskEvents` request
* Execute one filtered query for a given USERID, ordered by descending time: `Run filteredTaskEvents` request

The execution returns an JSON array of values like the following:
```json
[ [ 27.0, 83.0, 1632145611000, "ACTIVATED", "2", "rhpamAdmin" ], [ 26.0, 80.0, 1632144420000, "ACTIVATED", "1", "rhpamAdmin" ] ]
```

A custom mapper can be registered using the provided [TaskEventsMapper](./TaskEventsMapper) Java project that generates 
a new mapper named `TaskEvents`. This can be to use in the `mapper` parameter of the execution query to generate a more
detailed response like:
```json
[ {
  "taskId" : 27,
  "id" : 83,
  "logTime" : 1632145611000,
  "type" : "ACTIVATED",
  "value" : "2",
  "userId" : "rhpamAdmin"
}, {
  "taskId" : 26,
  "id" : 80,
  "logTime" : 1632144420000,
  "type" : "ACTIVATED",
  "value" : "1",
  "userId" : "rhpamAdmin"
} ]
```

Once built, the associated jar archive must be deployed under JBOSS_HOME/standalone/deployments/kie-server.war/WEB-INF/lib
(server must be restarted to activate it)

**Note**: the Maven project depends on the artifact `com.temenos.infinity:OnboardingPAMAggregator:2021.01.00` that is defined
in the shared `BPM.zip` collection, so you also need to build this project first.
