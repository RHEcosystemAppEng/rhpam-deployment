-- LatestTaskVariable collects the latest value of every variable, for each task
CREATE OR REPLACE VIEW LatestTaskVariable AS
SELECT
    (SELECT value FROM TaskVariableImpl maxTvi WHERE maxTvi.id=max(tvGroup.id)) as value,
    taskId,
    name
FROM
    TaskVariableImpl tvGroup
GROUP BY taskId, name
ORDER BY taskId, name
-- Same but for H2 DB
CREATE OR REPLACE VIEW LatestTaskVariable AS
SELECT
    (SELECT value FROM TaskVariableImpl maxTvi WHERE maxTvi.id=
        (SELECT max(t.id) FROM TaskVariableImpl t WHERE t.taskId=tvGroup.taskId AND t.name=tvGroup.name)) AS value,
    taskId,
    name
FROM
    TaskVariableImpl tvGroup
GROUP BY taskId, name
ORDER BY taskId, name

-- LatestProcessVariable collects the latest value of every variable, for each process instance
CREATE OR REPLACE VIEW LatestProcessVariable AS
SELECT
    (SELECT value FROM VariableInstanceLog maxVil WHERE maxVil.id=max(vilGroup.id)) as value,
    processInstanceId,
    variableId
FROM
    VariableInstanceLog vilGroup
GROUP BY processInstanceId, variableId
ORDER BY processInstanceId, variableId
-- Same but for H2 DB
CREATE OR REPLACE VIEW LatestProcessVariable AS
SELECT
    (SELECT value FROM VariableInstanceLog maxVil WHERE maxVil.id=
        (SELECT max(vil.id) FROM VariableInstanceLog vil WHERE
        vil.processInstanceId=vilGroup.processInstanceId AND
        vil.variableId=vilGroup.variableId)) AS value,
    processInstanceId,
    variableId
FROM
    VariableInstanceLog vilGroup
GROUP BY processInstanceId, variableId
ORDER BY processInstanceId, variableId

--
CREATE OR REPLACE View CustomView AS
select t.id as taskId, t.description,
       taskType.value  as taskType, requestId.value as requestId,
       partyId.value as partyId, facilityId.value as facilityId,
       stage.value as stage, overview.value as overview, counter.value as counter,
       nil.sla_due_date as slaDueDate,
       audit.dueDate, audit.lastModificationDate, t.status,
       t.actualOwner_id as actualOwner,
       (select GROUP_CONCAT(entity_id SEPARATOR ', ')
        FROM PeopleAssignments_PotOwners po WHERE po.task_id =t.id order by entity_id ASC) as potentialOwners
from  AuditTaskImpl audit JOIN Task t on audit.taskId=t.id
      JOIN NodeInstanceLog nil on nil.workItemId = t.workItemId
      left outer join LatestTaskVariable taskType ON taskType.taskId = t.id AND taskType.name like 'taskType'
      left outer join LatestTaskVariable requestId ON requestId.taskId = t.id AND requestId.name like 'requestId'
      left outer join LatestTaskVariable facilityId ON facilityId.taskId = t.id AND facilityId.name like 'facilityId'
      left outer join LatestTaskVariable partyId ON partyId.taskId = t.id AND partyId.name like 'partyId'
      left outer join LatestProcessVariable stage ON t.processInstanceId=stage.processInstanceId AND stage.variableId like 'stage'
      left outer join LatestTaskVariable overview ON overview.taskId = t.id AND overview.name like 'overview'
      left outer join LatestProcessVariable counter ON t.processInstanceId=stage.processInstanceId AND counter.variableId like 'count'
