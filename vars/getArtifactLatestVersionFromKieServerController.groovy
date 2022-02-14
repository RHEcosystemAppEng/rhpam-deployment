/**
 *
 * @param server - server dns/ip along with :port(for example : ipaddress:8080) of business central
 * @param userName - user name of controller user with role 'rest-all'
 * @param password - password of the above username.
 * @param groupId - group id of artifact to be deployed
 * @param artifactId -artifact name to be deployed
 * @param version - the version of the artifact
 * @param kieServerId - the name of the kie-server.
 * @return the version of the artifact if it's deployed, otherwise returns blank
 */
def call(String server,String userName,String password, String groupId , String artifactId, String version,String kieServerId )
{

    echo "started getArtifactLatestVersionFromKieServerController/7"
    def contextUrl = "/business-central/rest/controller/management/servers/${kieServerId}/containers"
    String url = "https://$server$contextUrl"
//    echo "url= ${url}"
//    echo "user= ${userName}"


    def allContainers = sh(script: "curl --user ${userName}:${password} -X GET ${url} --header 'Accept: application/json' ",returnStdout : true)


    echo "the containers in kie-server : \\n  ${allContainers}"

// Iterate over all containers and for the inputted artifact and group id,  takes the version that is deployed, if there is no container installed,
    // return space.

    def resultVersion = "";
    def containers = readJSON text: allContainers
    if(!containers["container-spec"].isEmpty()) {
        containers["container-spec"].each { container ->
            def currentGroupId = container["release-id"]["group-id"]
            def currentArtifactId = container["release-id"]["artifact-id"]
            if (groupId.equals(currentGroupId) && artifactId.equals(currentArtifactId)) {
                resultVersion = container["release-id"].version
            }
        }
    }

    return resultVersion
}

