package com.redhat.workItem;

import org.jboss.logging.Logger;

import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import java.util.ArrayList;
import java.util.List;

import static java.lang.String.format;

@Path("/doyourservice")
public class ServiceResource {
    private static final Logger LOG = Logger.getLogger(ServiceResource.class);

    private List<Item> items = new ArrayList<>();

    @POST
    @Produces(MediaType.TEXT_PLAIN)
    @Consumes(MediaType.APPLICATION_JSON)
    public String apply(Item item) {
        items.add(item);
        LOG.infof("Adding item: %s", item);
        return format("Executing %s: %s", item.getName(), item.getDescription());
    }

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Item> services() {
        LOG.infof("Retuning items: %s", items);
        return items;
    }
}