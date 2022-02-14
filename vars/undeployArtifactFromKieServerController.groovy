package org.demo
/**
 *
 * @param server - server dns/ip along with :port(for example : ipaddress:8080) of business central
 * @param userName - user name of controller user with role 'rest-all'
 * @param password - password of the above username.
 * @param containerId - artifactId Concatenated with _@paramversion
 * @param groupId - group id of artifact to be undeployed
 * @param artifactId -artifact name to be undeployed
 * @param version - the version of the artifact to be undeployed
 * @param kieServerId - the name of the kie-server.
 * @return string result from business central controller's response
 */
def call(String server,String userName,String password,String containerId,String kieServerId )
{
    echo "started undeployArtifactFromKieServerController/5"
    def contextUrl = "/business-central/rest/controller/management/servers/${kieServerId}/containers/"
    def url = "https://" + server + contextUrl + containerId
    def userPass = userName + ":" + password;
    def result = sh(script: "curl --user ${userPass} --location --request DELETE ${url} \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json'",returnStdout : true)

    echo "result is ${result}"
    return result
}

