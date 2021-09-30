

| Feature | Feasible | Details |
|---|---|---|
|Extension REST endpoint | :white_check_mark: | Use standard JAX-RS annotations in your java classes, e.g. `@Path("/greeting")`|
|Create custom image| :white_check_mark: | See (1) |
|Use external Maven mirror| :white_check_mark: | See (2)|
|Immutable server| :white_check_mark: | Not needed, Kogito service is immutable by nature |
|MS-SQL DB| :question: | **TO BE DISCUSSED**|
|Custom Work Item Handler | :question: | **TO BE DISCUSSED**: the concept is mentioned in the guide, but seems a different Java interface |
|Use given version of Kogito platform | :question: | **TO BE VERIFIED**: Is the version in the POM sufficient to control the entire Kogito platform? |
|Integration with Keycloak | :white_check_mark: | Through the Keycloak operator |
| Register and run custom DB queries, see (3)| :question: | **TO BE DISCUSSED**: seems no more available, is there any replacement for that, like GraphQL queries? |
| Persist Data Objects in separate JPA persistence module | :question: | **TO BE DISCUSSED**: it should be doable, since it's a Java application after all |


(1) Image is created during the deployment of the Kogito app, so it is created for us by the operator.
Anyway, if we want to generate it offline and reuse it later we need to clarify the procedure to:
* Generate the image offline
* Activate it as part of the deployment

Please note that a single RHPAM server image can be divided into multiple Kogito app and images, depending on the selected
split strategy.

(2) "If you have configured an internal Maven repository, you can use it as a Maven 
mirror service and specify the Maven mirror URL in your Kogito build definition to substantially shorten build time"
```yaml
spec:
  mavenMirrorURL: http://nexus3-nexus.apps-crc.testing/repository/maven-public/
```
(3) One of the customer requests that we are supporting is about having a REST service to fetch the list of the active tasks,
including details on status, task and process variables and owners. The service has to provide full filtering options, with
all the common SQL operators, and also pagination and sorting capabilities.
The proposed solution is based on a registered custom query, which, in turn, requires to define a custom DB view to expose 
all the variables as explicit DB columns on which we can apply the required filter.  
