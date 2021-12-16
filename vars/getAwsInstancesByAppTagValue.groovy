def call(String keyApplicationName,String appName)
{

    echo "started getInstanceByAppTagValue/2"
    def result = sh(script: "aws ec2 describe-tags --filters \"Name=resource-type,Values=instance\" \"Name=tag:${keyApplicationName},Values=${appName}\"",returnStdout : true)

    echo "result is ${result}"
    return result
}
