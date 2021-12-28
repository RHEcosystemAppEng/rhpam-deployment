def call(String instanceId)
{
    echo "started stopInstanceAWS/1"
    def result = sh(script : "aws ec2 stop-instances --instance-ids ${instanceId}" ,returnStdout: true).trim()
    echo "result is ${result}"
    return result;
}
