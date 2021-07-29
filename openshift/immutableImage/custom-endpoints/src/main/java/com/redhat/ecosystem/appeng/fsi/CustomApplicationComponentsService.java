package com.redhat.ecosystem.appeng.fsi;

import org.jbpm.services.api.UserTaskService;
import org.kie.server.services.api.KieServerApplicationComponentsService;
import org.kie.server.services.api.KieServerRegistry;
import org.kie.server.services.api.SupportedTransports;
import org.kie.server.services.jbpm.JbpmKieServerExtension;
import org.kie.server.services.jbpm.UserTaskServiceBase;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;

public class CustomApplicationComponentsService implements KieServerApplicationComponentsService {
    private static final Logger logger = LoggerFactory.getLogger(CustomApplicationComponentsService.class);

    private static final String OWNER_EXTENSION = JbpmKieServerExtension.EXTENSION_NAME;

    public Collection<Object> getAppComponents(String extension, SupportedTransports type, Object... services) {
        if (!OWNER_EXTENSION.equals(extension)) {
            logger.debug("Invoked getAppComponents with unmanaged extension: {}/{}", extension, type);
            return Collections.emptyList();
        }
        logger.info("Invoked getAppComponents with: {}/{}", extension, type);

        List<Object> components = new ArrayList<>(1);
        if (SupportedTransports.REST.equals(type)) {
            Arrays.stream(services).forEach(o ->
                    logger.debug("Received object of type {}", o.getClass()));
            KieServerRegistry context = Arrays.stream(services).filter(
                    o -> KieServerRegistry.class.isAssignableFrom(o.getClass())
            ).map(KieServerRegistry.class::cast).findFirst().orElse(null);
            UserTaskService userTaskService = Arrays.stream(services).filter(
                    o -> UserTaskService.class.isAssignableFrom(o.getClass())
            ).map(UserTaskService.class::cast).findFirst().orElse(null);
            UserTaskServiceBase userTaskServiceBase = new UserTaskServiceBase(userTaskService, context);

            logger.debug("KieServerRegistry is {}", context);
            logger.debug("UserTaskService is {}", userTaskService);
            logger.debug("UserTaskServiceBase is {}", userTaskServiceBase);
            components.add(new CustomResource(userTaskServiceBase));
        }

        logger.info("Invoked getAppComponents. Returning: {}", components);
        return components;
    }
}