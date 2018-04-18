#!/bin/bash

project_location="/Users/kevingraham/Documents/Development/java/twitter_sentiment"
project_name="twitter_sentiment"
pem_location="/Users/kevingraham/.ssh/kev-cli-key.pem"
war_file="$project_name-1.0-SNAPSHOT"

# launch instance
echo "Creating EC2 instance..."
instance_id=$(aws ec2 run-instances --image-id ami-25615740 --security-group-ids sg-ddcce4b6 --count 1 --instance-type t2.micro --key-name kev-cli --query 'Instances[0].InstanceId' --output text)
echo "Instance ID: $instance_id"

# name instance
aws ec2 create-tags --resource $instance_id --tags Key=Name,Value=$project_name 

# build project
echo "Building project..."

cd $project_location
mvn -q clean
mvn -q compile
mvn -q package

# wait until instance has launched
echo "Waiting for instance to launch..."
aws ec2 wait instance-running --instance-ids $instance_id

# get instance state
instance_state=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].State.Name')
echo "Instance State: $instance_state"

# get instance IP address
instance_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].PublicIpAddress')
instance_ip=${instance_ip//\"/}
echo "Instance IP: $instance_ip"

# get endpoint
instance_ip_cleaned=${instance_ip//\./-}
endpoint="ec2-$instance_ip_cleaned.us-east-2.compute.amazonaws.com"
echo "Endpoint: $endpoint"

# copy war file to server
echo "copying war file to server..."
scp -i $pem_location target/$war_file.war ec2-user@$endpoint:~

# connect to server
echo "connecting to server..."
ssh -i $pem_location ec2-user@$endpoint << EOF

# install java 1.8
echo "Installing Java 8..."
sudo yum install java-1.8.0;

# remove java 1.7
echo "Removing Java 7..."
sudo yum remove java-1.7.0-openjdk;

# install tomcat
echo "Installing Tomcat..."
sudo yum install tomcat8-webapps tomcat8-admin-webapps;

# move war file
echo "moving war file...";
cd /usr/share/tomcat8/webapps;
sudo mv ~/*.war . ;
ls;

pwd;

# restart tomcat
echo "restarting tomcat...";
sudo tomcat8 stop;
sudo tomcat8 start;

# get deployment location
deployment_location=$instance_ip:8080/$war_file/ ;

echo "Project deployed at $deployment_location";

EOF
