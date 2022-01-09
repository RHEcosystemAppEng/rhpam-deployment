/**
 *
 * @param launchConfigName -  the name of the launch configuration , including version in the suffix.
 * @param imageId - the AMI image id to start up the instances from.
 * @param instanceType - the desired instance type.
 * @param pathToFile - the path of the script file in the context/workspace directory, that will be the user-data.
 * @return result of the command
 */
//updates ASG with new launch configuration
def call(String asgName,String launchConfigName)
{
    echo "started updateAutoScalingGroup/2"
    def result = sh(script : "aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${asgName}  \
                               --launch-configuration-name ${launchConfigName}",returnStdout: true).trim()

    echo "result is ${result}"
    return result;
}
