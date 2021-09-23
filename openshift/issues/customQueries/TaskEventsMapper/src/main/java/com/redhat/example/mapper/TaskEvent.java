package com.redhat.example.mapper;

import java.util.Date;

public class TaskEvent {
    private long taskId;
    private long id;
    private Date logTime;
    private String type;
    private String value;
    private String userId;

    public TaskEvent() {
    }

    public TaskEvent(long taskId, long id, Date logTime, String type, String value, String userId) {
        this.taskId = taskId;
        this.id = id;
        this.logTime = logTime;
        this.type = type;
        this.value = value;
        this.userId = userId;
    }

    public long getTaskId() {
        return taskId;
    }

    public void setTaskId(long taskId) {
        this.taskId = taskId;
    }

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public Date getLogTime() {
        return logTime;
    }

    public void setLogTime(Date logTime) {
        this.logTime = logTime;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getValue() {
        return value;
    }

    public void setValue(String value) {
        this.value = value;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }
}
