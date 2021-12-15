package org.demo

def call(String server,String userName,String password,String containerId, String groupId , String artifactId, String version )
{
    echo "started deployToKieServerArtifact/7"
    def contextUrl = "/kie-server/rest/server/containers/"
    def url = "http://" + server + contextUrl + containerId
    def userPass = userName + ":" + password;
    def basicAuthBase64 = sh(script: "echo $userPass | base64",returnStdout: true ).trim()
//    echo "result is ${basicAuthBase64}"
    def result = sh(script: "curl -s  --location --request PUT ${url} \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --header '${basicAuthBase64}' \
             --data '{\"container-id\" : \"${containerId}\",\"release-id\" : { \"group-id\" : \"${groupId}\",\"artifact-id\" : \"${artifactId}\",\"version\" : \"${version}\" }}'",returnStdout : true)

    echo "result is ${result2}"
    return result
}

