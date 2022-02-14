/**
 *
 * @param server - business-central dns/ip address along with :port(example ip_address:8080).
 * @param userName - user name of controller user with role 'rest-all'
 * @param password - password of the above username
 * @return json string containing a json array with all kie-server registered with business-central.
 */
def call(String server,String userName,String password)
{

    echo "started getAllKieServersInJson/3"
    def contextUrl = "/business-central/rest/controller/management/servers"
    String url = "https://$server$contextUrl"

    def allKieServers = sh(script: "curl --user ${userName}:${password} -X GET ${url} --header 'Accept: application/json' ",returnStdout : true)


    echo "the kie-servers list : \\n  ${allKieServers}"

    return allKieServers
}

