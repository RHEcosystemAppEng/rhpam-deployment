def String getInstanceByAppTagValue(String appName)
{


    def result = sh(script: "aws ec2 describe-tags --filters \"Name=resource-type,Values=instance\" \"Name=app,Values=${appName}\"",returnStdout : true)

    echo "result is ${result}"
    return result
}

def void authenticateAWS(String accessKey,String secretKey,String region)
{
    sh(script: "aws configure set aws_access_key_id ${accessKey}",returnStdout : true)
    sh(script: "aws configure set aws_secret_access_key ${secretKey}",returnStdout : true)
    sh(script: "aws configure set  default.region ${region}",returnStdout : true)

}

retrun this