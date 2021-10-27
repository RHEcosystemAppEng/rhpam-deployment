package com.redhat.ecosystem.appeng.fsi;

import io.swagger.annotations.*;
import org.jbpm.services.api.TaskNotFoundException;
import org.kie.server.services.jbpm.UserTaskServiceBase;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.ws.rs.*;
import javax.ws.rs.core.*;
import java.text.MessageFormat;
import java.util.Map;

import static org.kie.server.remote.rest.common.util.RestUtils.*;

@Path("extension/custom-api/")
public class CustomResource {

    private static final Logger logger = LoggerFactory.getLogger(CustomResource.class);
    private static final String GET_TASK_RESPONSE_JSON = "TBD";
    private static final String TASK_INSTANCE_NOT_FOUND = "Could not find task instance with id \"{0}\"";

    private UserTaskServiceBase userTaskServiceBase;

    public CustomResource() {
    }

    public CustomResource(UserTaskServiceBase userTaskServiceBase) {
        this.userTaskServiceBase = userTaskServiceBase;
    }

    @ApiOperation(value = "Returns output data for a specified task instance.",
            response = Map.class)
    @ApiResponses(value = {@ApiResponse(code = 500, message = "Unexpected error"), @ApiResponse(code = 404, message = "Task with given id not found"),
            @ApiResponse(code = 200, message = "Successfull response", examples = @Example(value = {
                    @ExampleProperty(mediaType = MediaType.APPLICATION_JSON, value = GET_TASK_RESPONSE_JSON)}))})
    @GET
    @Path("{containerId}/{taskInstanceId}")
    @Consumes({MediaType.APPLICATION_XML, MediaType.APPLICATION_JSON})
    @Produces({MediaType.APPLICATION_XML, MediaType.APPLICATION_JSON})
    public Response getTask(@Context HttpHeaders headers,
                            @PathParam("containerId") String containerId,
                            @PathParam("taskInstanceId") Long taskInstanceId) {
        Variant v = getVariant(headers);
        String contentType = getContentType(headers);

        try {
            logger.info("Getting task {} of container {}", taskInstanceId, containerId);
            String task = userTaskServiceBase.getTask(containerId, taskInstanceId, true, true, true, contentType);
            logger.info("Returning task content '{}'", task);
            return createResponse(task, v, Response.Status.OK);
        } catch (TaskNotFoundException e) {
            return notFound(errorMessage(e, MessageFormat.format(TASK_INSTANCE_NOT_FOUND, taskInstanceId)), v);
        } catch (Exception e) {
            String response = "Execution failed with error : " + e.getMessage();
            logger.error("Returning Failure response with content '{}'", response, e);
            return createResponse(e.getMessage(), v, Response.Status.INTERNAL_SERVER_ERROR);
        }
    }

    @ApiOperation(value = "Skips a specified task instance within the sequence of tasks in the process instance",
            code = 201)
    @ApiResponses(value = {@ApiResponse(code = 500, message = "Unexpected error"), @ApiResponse(code = 404, message = "Task with given id not found")})
    @PUT
    @Path("{containerId}/{taskInstanceId}/skip")
    @Consumes({MediaType.APPLICATION_XML, MediaType.APPLICATION_JSON})
    @Produces({MediaType.APPLICATION_XML, MediaType.APPLICATION_JSON})
    public Response skipTask(@Context HttpHeaders headers,
                             @PathParam("containerId") String containerId,
                             @PathParam("taskInstanceId") Long taskInstanceId,
                             @QueryParam("user") String userId) {
        Variant v = getVariant(headers);

        try {
            logger.info("Skipping task {} of container {} for user {}", taskInstanceId, containerId, userId);
            userTaskServiceBase.skip(containerId, taskInstanceId, userId);
            logger.info("Task skipped");
            return createResponse("", v, Response.Status.CREATED);
        } catch (TaskNotFoundException e) {
            return notFound(errorMessage(e, MessageFormat.format(TASK_INSTANCE_NOT_FOUND, taskInstanceId)), v);
        } catch (Exception e) {
            String response = "Execution failed with error : " + e.getMessage();
            logger.debug("Returning Failure response with content '{}'", response);
            return createResponse(response, v, Response.Status.INTERNAL_SERVER_ERROR);
        }
    }
}
