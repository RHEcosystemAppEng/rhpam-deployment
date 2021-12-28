def call(String instanceId)
{
    echo "started waitForInstanceToBeStoppedAWS/1"
    def result = sh(script : "aws ec2 wait instance-stopped --instance-ids ${instanceId}" ,returnStdout: true).trim()
    echo "Instance became in Stopped State Successfully"
    echo "result is ${result}"
    return result;
}
