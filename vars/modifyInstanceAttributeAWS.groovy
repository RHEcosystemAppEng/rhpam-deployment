def call(String instanceId,String theAttribute,String theValue)
{

    echo "started modifyInstanceAttributeAWS/3"
    def result = sh(script : "aws ec2 modify-instance-attribute --instance-id ${instanceId} --attribute ${theAttribute} --value ${theValue} " ,returnStdout: true).trim()

    echo "result is ${result}"
    return result
}
