CREATE OR REPLACE View CustomView AS
select t.id as taskId, t.description,
       taskType.value  as taskType, requestId.value as requestId,
       partyId.value as partyId, facilityId.value as facilityId,
       stage.value as stage, overview.value as overview, counter.value as counter,
       audit.dueDate, audit.lastModificationDate, t.status,
       t.actualOwner_id as actualOwner,
       (select GROUP_CONCAT(entity_id SEPARATOR ', ')
        FROM PeopleAssignments_PotOwners po WHERE po.task_id =t.id order by entity_id ASC) as potentialOwners
from  AuditTaskImpl audit JOIN Task t on audit.taskId=t.id
                          left outer join TaskVariableImpl taskType ON taskType.taskId = t.id AND taskType.name like 'taskType'
                          left outer join TaskVariableImpl requestId ON requestId.taskId = t.id AND requestId.name like 'requestId'
                          left outer join TaskVariableImpl facilityId ON facilityId.taskId = t.id AND facilityId.name like 'facilityId'
                          left outer join TaskVariableImpl partyId ON partyId.taskId = t.id AND partyId.name like 'partyId'
                          left outer join VariableInstanceLog stage ON t.processInstanceId=stage.processInstanceId AND stage.id in (select MAX(v.id) from VariableInstanceLog v where v.variableId like 'stage' AND v.processInstanceId=t.processInstanceId)
                          left outer join TaskVariableImpl overview ON overview.taskId = t.id AND overview.name like 'overview'
                          left outer join VariableInstanceLog counter ON t.processInstanceId=stage.processInstanceId AND counter.id in (select MAX(v.id) from VariableInstanceLog v where v.variableId like 'counter' AND v.processInstanceId=t.processInstanceId)
