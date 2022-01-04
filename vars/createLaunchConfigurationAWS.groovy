/**
 *
 * @param launchConfigName -  the name of the launch configuration , including version in the suffix.
 * @param imageId - the AMI image id to start up the instances from.
 * @param instanceType - the desired instance type.
 * @param pathToFile - the path of the script file in the context/workspace directory, that will be the user-data.
 * @return result of the command
 */
//create a new launch configuration
def call(String launchConfigName,String imageId,String instanceType,String pathToFile,String securityGroupdId,String awsRegion)
{
    echo "started createLaunchConfigurationAWS/5"
    def result = sh(script : "aws autoscaling create-launch-configuration --launch-configuration-name ${launchConfigName} \
                              --image-id ${imageId}  --instance-type ${instanceType} \
                              --security-groups ${securityGroupdId} --region ${awsRegion} \
                              --user-data ${pathToFile}",returnStdout: true).trim()
    echo "result is ${result}"
    return result
}
