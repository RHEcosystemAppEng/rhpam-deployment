package org.demo
/**
 *
 * @param server - server dns/ip along with :port(for example : ipaddress:8080) of business central
 * @param userName - user name of controller user with role 'rest-all'
 * @param password - password of the above username.
 * @param containerId - artifactId Concatenated with _@paramversion
 * @param groupId - group id of artifact to be deployed
 * @param artifactId -artifact name to be deployed
 * @param version - the version of the artifact
 * @param kieServerId - the name of the kie-server.
 * @return string result from business central controller's response
 */
def call(String server,String userName,String password,String containerId, String groupId , String artifactId, String version,String kieServerId )
{
    echo "started deployToKieServerArtifactController/8"
    def contextUrl = "/business-central/rest/controller/management/servers/${kieServerId}/containers/"
    def url = "https://" + server + contextUrl + containerId
    def userPass = userName + ":" + password;
//    def basicAuthBase64 = sh(script: "echo -n $userPass | base64",returnStdout: true ).trim()
//    def authHeader = "Authorization: Basic " + basicAuthBase64
//    echo "result is ${basicAuthBase64}"
    def result = sh(script: "curl --user ${userPass} --location --request PUT ${url} \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
             --data '{\n" +
            "  \"container-id\" : \"${artifactId}_${version}\",\n" +
            "  \"container-name\" : \"${artifactId}\",\n" +
            "  \"server-template-key\" : null,\n" +
            "  \"release-id\" : {\n" +
            "    \"group-id\" : \"${groupId}\",\n" +
            "    \"artifact-id\" : \"${artifactId}\",\n" +
            "    \"version\" : \"${version}\"\n" +
            "  },\n" +
            "  \"configuration\" : {\n" +
            "    \"RULE\" : {\n" +
            "      \"org.kie.server.controller.api.model.spec.RuleConfig\" : {\n" +
            "        \"pollInterval\" : null,\n" +
            "        \"scannerStatus\" : \"STOPPED\"\n" +
            "      }\n" +
            "    },\n" +
            "    \"PROCESS\" : {\n" +
            "      \"org.kie.server.controller.api.model.spec.ProcessConfig\" : {\n" +
            "        \"runtimeStrategy\" : \"SINGLETON\",\n" +
            "        \"kbase\" : \"\",\n" +
            "        \"ksession\" : \"\",\n" +
            "        \"mergeMode\" : \"MERGE_COLLECTIONS\"\n" +
            "      }\n" +
            "    }\n" +
            "  },\n" +
            "  \"status\" : \"STARTED\"\n" +
            "}'",returnStdout : true)

    echo "result is ${result}"
    return result
}

