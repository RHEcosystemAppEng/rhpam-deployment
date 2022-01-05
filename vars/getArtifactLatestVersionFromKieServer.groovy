//return the latest version deployed of a given artifact, if it's not deployed at all, return space
def call(String server,String userName,String password, String groupId , String artifactId, String version )
{

    echo "started getArtifactLatestVersionFromKieServer/6"
    def contextUrl = "/kie-server/services/rest/server/containers/"
    String url = "http://$server$contextUrl"
//    echo "url= ${url}"
//    echo "user= ${userName}"


    def allContainers = sh(script: "curl --user ${userName}:${password} -X GET ${url} --header 'Accept: application/json' ",returnStdout : true)


    echo "the containers in kie-server : \\n  ${allContainers}"

// Iterate over all containers and for the inputted artifact and group id,  takes the version that is deployed, if there is no container installed,
    // return space.
    def resultVersion = "";
    def containers = readJSON text: allContainers
    if(!containers.result["kie-containers"]["kie-container"].isEmpty()) {
        containers.result["kie-containers"]["kie-container"].each { container ->
            def currentGroupId = container["release-id"]["group-id"]
            def currentArtifactId = container["release-id"]["artifact-id"]
            if (groupId.equals(currentGroupId) && artifactId.equals(currentArtifactId)) {
                resultVersion = container["release-id"].version
            }
        }
    }

    return resultVersion
}

