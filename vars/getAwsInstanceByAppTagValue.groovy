def call(String appName)
{

    echo "started getInstanceByAppTagValue/1"
    def result = sh(script: "aws ec2 describe-tags --filters \"Name=resource-type,Values=instance\" \"Key=app,Values=${appName}\"",returnStdout : true)

    echo "result is ${result}"
    return result
}
