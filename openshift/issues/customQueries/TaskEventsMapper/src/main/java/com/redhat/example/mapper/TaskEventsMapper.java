package com.redhat.example.mapper;

import org.dashbuilder.dataset.DataSet;
import org.jbpm.kie.services.impl.query.mapper.AbstractQueryMapper;
import org.jbpm.services.api.query.QueryResultMapper;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class TaskEventsMapper extends AbstractQueryMapper<TaskEvent> implements QueryResultMapper<List<TaskEvent>> {
    public static final String COLUMN_TASKID = "TASKID";
    public static final String COLUMN_ID = "ID";
    public static final String COLUMN_LOGTIME = "LOGTIME";
    public static final String COLUMN_TYPE = "TYPE";
    public static final String COLUMN_VALUE = "VALUE";
    public static final String COLUMN_USERID = "USERID";

    @Override
    protected TaskEvent buildInstance(DataSet dataSetResult, int index) {
        TaskEvent taskEvent = new TaskEvent(
                getColumnLongValue(dataSetResult, COLUMN_TASKID, index),
                getColumnLongValue(dataSetResult, COLUMN_ID, index),
                getColumnDateValue(dataSetResult, COLUMN_LOGTIME, index),
                getColumnStringValue(dataSetResult, COLUMN_TYPE, index),
                getColumnStringValue(dataSetResult, COLUMN_VALUE, index),
                getColumnStringValue(dataSetResult, COLUMN_USERID, index)
        );
        return taskEvent;
    }

    @Override
    public List<TaskEvent> map(Object result) {
        if (result instanceof DataSet) {
            DataSet dataSetResult = (DataSet) result;
            List<TaskEvent> mappedResult = new ArrayList<>();

            if (dataSetResult != null) {

                for (int i = 0; i < dataSetResult.getRowCount(); i++) {
                    TaskEvent taskEvent = buildInstance(dataSetResult, i);
                    mappedResult.add(taskEvent);

                }
            }

            return mappedResult;
        }

        throw new IllegalArgumentException("Unsupported result for mapping " + result);

    }

    @Override
    public String getName() {
        return "TaskEvents";
    }

    @Override
    public Class<?> getType() {
        return TaskEvent.class;
    }

    @Override
    public QueryResultMapper<List<TaskEvent>> forColumnMapping(Map<String, String> columnMapping) {
        return new TaskEventsMapper();
    }
}

