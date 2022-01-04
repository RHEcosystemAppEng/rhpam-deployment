package org.demo

def call(String server,String userName,String password,String containerId)
{
//Command template to dispose/undeploy artifact from kie-server.
//    curl --user "<username>:<password>" -X DELETE http://<serverhost>:<serverport>/kie-server/services/rest/server/containers/<containerID>
    echo "started undeployArtifactFromKieServer/4"
    def contextUrl = "/kie-server/services/rest/server/containers/"
    def url = "http://" + server + contextUrl + containerId
    def userPass = userName + ":" + password;

    def result = sh(script: "curl --user ${userPass} -X DELETE ${url} \
            --header 'Accept: application/json' ",returnStdout : true)


    echo "result is ${result}"
    return result
}

