//start a stopped instance.
def call(String instanceId)
{
    echo "started startInstanceAWS/1"
    def result = sh(script : "aws ec2 start-instances --instance-ids ${instanceId}" ,returnStdout: true).trim()
    echo "result is ${result}"
    return result;
}
