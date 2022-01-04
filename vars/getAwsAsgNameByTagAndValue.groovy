def call(String tagKey,String tagValue)
{

    echo "started getAwsAsgNameByTagAndValue/2"
    def result = sh(script: "aws autoscaling describe-auto-scaling-groups --filters  \"Name=tag-key,Values=${tagKey}  Name=tag-value,Values=${tagValue}\" ",returnStdout : true)

    echo "result is ${result}"
    def resultJson = readJSON text : result
    String asgName = resultJson.AutoScalingGroups[0].AutoScalingGroupName

    return asgName
}
