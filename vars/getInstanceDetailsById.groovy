def call(String instanceId)
{

    echo "started getInstanceDetailsById/1"
    def result = sh(script : "aws ec2 describe-instances --instance-ids ${instanceId}",returnStdout: true).trim()

    echo "result is ${result}"
    return result
}
