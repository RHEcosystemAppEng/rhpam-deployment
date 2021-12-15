package org.demo

def call(String server,String userName,String password,String containerId, String groupId , String artifactId, String version )
{
    echo "started deployToKieServerArtifact/7"
    def contextUrl = "/kie-server/rest/server/containers/"
    def url = "http://" + server + contextUrl + containerId
    def userPass = userName + ":" + password;
    def basicAuthBase64 = sh(script: "echo -n $userPass | base64",returnStdout: true ).trim()
    def authHeader = "Authorization: Basic " + basicAuthBase64 
//    echo "result is ${basicAuthBase64}"
    def result = sh(script: "curl --location --request PUT ${url} \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --header '${authHeader}' \
             --data '{\"container-id\" : \"${containerId}\",\"release-id\" : { \"group-id\" : \"${groupId}\",\"artifact-id\" : \"${artifactId}\",\"version\" : \"${version}\" }}'",returnStdout : true)

    echo "result is ${result}"
    return result
}

