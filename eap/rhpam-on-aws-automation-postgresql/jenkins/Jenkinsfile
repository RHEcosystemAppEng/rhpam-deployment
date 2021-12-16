Library('shared-jenkins-library') _
node {
        //   stage('checkout repo from Git')
        //   {
            //   checkout scm
            // checkout([$class: 'GitSCM', branches: [[name: '*/zvikatest']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/RHEcosystemAppEng/rhpam-deployment']]])
    
        //   }
        def kieServersInstances
        def containerId = "test_1.0.0-SNAPSHOT"
        def groupId = 'com.myspace'
        def artifact = "test"
        def version = "1.0.0-SNAPSHOT"
        stage('Authentication To AWS') {
                
                withCredentials([usernamePassword(credentialsId: 'AWS_CREDENTIALS', passwordVariable: 'PASSWORD', usernameVariable: 'USER')]) {
                     authenticateAWS (USER, PASSWORD, 'us-east-1')
                 }
                 
        }
        
        stage('fetching instances by tag')
        {
            // getAwsInstancesByAppTagValue - call(String keyApplicationName,String appName)
            kieServersInstances = getAwsInstancesByAppTagValue("app","RHPAM-KS")
            // sh( script :  'aws ec2 describe-tags --filters Name=resource-type,Values=instance Name=tag:app,Values=RHPAM-KS',returnStdout : true).trim()
            
           
            
        }
        stage('Deploy artifact to KIeServers') {
            def jsonWithArray = readJSON text: kieServersInstances
            jsonWithArray.Tags.each{ json ->
                def instanceId = json.ResourceId
                // getInstanceDetailsById - call(String instanceId)
                def jsonInstance = getInstanceDetailsById(instanceId)
                def jsonS = readJSON text: jsonInstance
                
                def publicIpAddress = jsonS.Reservations["Instances"][0].PublicIpAddress.toString()
                
                echo "Deploying to instanceId: ${instanceId} , Ip Address ${publicIpAddress} "
                
                ipAddressStripped = publicIpAddress.substring(1,publicIpAddress.length()-1) + ":8080"
                
                withCredentials([usernamePassword(credentialsId: 'KS_CREDENTIALS', passwordVariable: 'PASSWORD', usernameVariable: 'USER')]) {
                    //deployToKieServerArtifact - def call(String server,String userName,String password,String containerId, String groupId , String artifactId, String version )
                     deployToKieServerArtifact (ipAddressStripped,USER, PASSWORD, containerId ,groupId ,artifact,version)
                     
                }                
           }
            
        }
            
        stage('Clean Workspace')
          {
              cleanWs()
          }
}
