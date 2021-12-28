//user_Data argument must be encoded in base64!.
def call(String instanceId,String user_Data)
{

    echo "started modifyInstanceUserDataAWS/2"
    def result = sh(script : "aws ec2 modify-instance-attribute --instance-id ${instanceId} --attribute userData --value ${user_Data} " ,returnStdout: true).trim()

    echo "result is ${result}"
    return result
}
