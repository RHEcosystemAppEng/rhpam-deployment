def call(String resourceName,String keyName,String keyValue)
{

    echo "started getAwsResourceByTagAndValue/3"
    def result = sh(script: "aws ec2 describe-tags --filters \"Name=resource-type,Values=${resourceName}\" \"Name=tag:${keyName},Values=${keyValue}\"",returnStdout : true)

    echo "result is ${result}"
    return result
}
