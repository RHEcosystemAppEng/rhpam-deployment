/**
 *
 * @param launchConfigName -  the name of the launch configuration , including version in the suffix.
 * @param imageId - the AMI image id to start up the instances from.
 * @param instanceType - the desired instance type.
 * @param pathToFile - the path of the script file in the context/workspace directory, that will be the user-data.
 * @return file location in workspace including file:// prefix
 */
//create a new GAV of the latest version for artifact, in order to pass it later to user-data property
def call(String groupId , String artifactId, String version )
{
    String gav = 'latest-artifact-gav=' + groupId + ':' + artifactId + ':' + version
    echo 'started createLatestArtifactGavInWorkspace/3'

    sh(script: "echo ${gav} > ./gav.out")
    sh(script: "cat ./gav.out | base64 > ./gav-base64.out")
    def pwd= sh(script: "pwd" , returnStdout : true).trim()
    def result = "file://$pwd/gav.out"
    def jsonElement=["artifacts":[["artifact_id": "${artifactId}", "group_id": "${groupId}", "version": "${version}"]]]
    writeJSON file: 'json.out' , json: jsonElement
    result = "file://$pwd/json.out"
    echo "file location= ${result}"
    return result
}