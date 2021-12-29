package org.demo

//return the latest version deployed of a given artifact, if it's not deployed at all, return space
def call(String server,String userName,String password, String groupId , String artifactId, String version )
{

//    curl --user "<username>:<password>" -X DELETE http://<serverhost>:<serverport>/kie-server/services/rest/server/containers/<containerID>
    echo "started getArtifactLatestVersionFromKieServer/6"
    def contextUrl = "/kie-server/services/rest/server/containers/"
    def url = "http://" + server + contextUrl
    def userPass = userName + ":" + password;

    def result = sh(script: '''curl --user $userPass --X GET $url \
            --header 'Accept: application/json' ''',returnStdout : true)
    //TO DO Iterate over all containers and for the inputted artifact and group id,  takes the version that is deployed, if there is no container installed,
    // return space.

    echo "result is ${result}"
    return result
}

