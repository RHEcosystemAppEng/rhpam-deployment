package org.demo;


def call(String accessKey,String secretKey,String region)
{
    echo "started authenticateAWS/3"
    sh(script: "aws configure set aws_access_key_id ${accessKey}",returnStdout : true)
    sh(script: "aws configure set aws_secret_access_key ${secretKey}",returnStdout : true)
    sh(script: "aws configure set  default.region ${region}",returnStdout : true)

}

