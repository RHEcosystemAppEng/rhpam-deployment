package com.redhat.workItem;

import lombok.Data;

@Data
public class Item {
    private String name;
    private String description;

    public Item() {
    }

    public Item(String name, String description) {
        this.name = name;
        this.description = description;
    }
}