/*
 * Copyright 2020 Red Hat, Inc. and/or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.redhat.ecosystem.appeng.fsi;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.URLConnection;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.net.URL;
import java.io.BufferedInputStream;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.jbpm.process.workitem.core.AbstractLogOrThrowWorkItemHandler;
import org.jbpm.process.workitem.core.util.RequiredParameterValidator;
import org.kie.api.runtime.process.WorkItem;
import org.kie.api.runtime.process.WorkItemManager;
import org.jbpm.process.workitem.core.util.Wid;
import org.jbpm.process.workitem.core.util.WidParameter;
import org.jbpm.process.workitem.core.util.WidResult;
import org.jbpm.process.workitem.core.util.service.WidAction;
import org.jbpm.process.workitem.core.util.service.WidAuth;
import org.jbpm.process.workitem.core.util.service.WidService;
import org.jbpm.process.workitem.core.util.WidMavenDepends;

@Wid(widfile = "ItemsLoader.wid", name = "ItemsLoader",
        displayName = "Items Loader",
        defaultHandler = "mvel: new com.redhat.ecosystem.appeng.fsi.ItemsLoaderWorkItemHandler()",
        documentation = "custom-work-item-handler/index.html",
        category = "Custom",
        icon = "ItemsLoader.png",
        parameters = {
                @WidParameter(name = "name", required = true)
        },
        results = {
                @WidResult(name = "noOfItems"),
                @WidResult(name = "items")
        },
        mavenDepends = {
                @WidMavenDepends(group = "com.redhat.ecosystem.appeng.fsi", artifact = "custom-work-item-handler", version = "1.0.0-SNAPSHOT")
        },
        serviceInfo = @WidService(category = "Custom", description = "${description}",
                keywords = "",
                action = @WidAction(title = "Items Loader"),
                authinfo = @WidAuth(required = true, params = {"name"},
                        paramsdescription = {"name"},
                        referencesite = "referenceSiteURL")
        )
)
public class ItemsLoaderWorkItemHandler extends AbstractLogOrThrowWorkItemHandler {
    private String name;

    public ItemsLoaderWorkItemHandler(String name) {
        this.name = name;
    }

    public void executeWorkItem(WorkItem workItem, WorkItemManager manager) {
        try {
            RequiredParameterValidator.validate(this.getClass(), workItem);

            // sample parameters
            name = (String) workItem.getParameter("name");
            System.out.println("Starting Items Loader with name=" + name);

            // complete workitem impl...
//            URL url = new URL("http://localhost:8888/doyourservice");
            URL url = new URL("http://work-item-service-dmartino-immutable.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com/doyourservice");
            URLConnection urlConnection = url.openConnection();
            System.out.println("Reading items from " + url);

            try (
                    BufferedReader in = new BufferedReader(
                            new InputStreamReader(
                                    urlConnection.getInputStream()));) {

                String inputLine;
                StringBuffer stringBuffer = new StringBuffer();
                while ((inputLine = in.readLine()) != null) {
                    stringBuffer.append(inputLine);
                }

                ObjectMapper objectMapper = new ObjectMapper();
                List items = objectMapper.readValue(stringBuffer.toString(), List.class);

                System.out.println("Got " + items.size() + " items");
                items.forEach(i -> System.out.println("Got " + i));

                HashMap result = new HashMap();
                result.put("noOfItems", items.size());
                result.put("items", items);
                manager.completeWorkItem(workItem.getId(), result);
            }
        } catch (Throwable cause) {
            handleException(cause);
        }
    }

    @Override
    public void abortWorkItem(WorkItem workItem,
                              WorkItemManager manager) {
        // stub
    }
}


