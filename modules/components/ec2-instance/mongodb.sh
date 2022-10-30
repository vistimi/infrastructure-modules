#!/bin/bash

# mount S3 bucket for mongodb
sudo yum update all
sudo yum update -y
sudo yum install automake fuse fuse-devel gcc-c++ git libcurl-devel libxml2-devel make openssl-devel -y

# aws configure set region ${aws_region}
# aws configure set profile ${aws_profile}
# aws configure set aws_access_key_id ${aws_access_key}
# aws configure set aws_secret_access_key ${aws_secret_key}

aws s3 cp s3://${bucket_name_mount_helper}/s3fs-fuse/ /home/ec2-user/s3fs-fuse --recursive

cd s3fs-fuse
chmod +x autogen.sh
sudo ./autogen.sh
./configure --prefix=/usr --with-openssl
make
sudo make install

sudo touch /etc/passwd-s3fs
sudo chmod 640 /etc/passwd-s3fs
sudo echo ${aws_access_key}:${aws_secret_key} | sudo tee /etc/passwd-s3fs

sudo mkdir /mys3bucket
sudo s3fs ${bucket_name_mongodb} -o use_cache=/tmp -o allow_other -o uid=1001 -o mp_umask=002 -o multireq_max=5 -o nonempty /mys3bucket

# script file for remounting
sudo yum install docker -y
# which s3fs
# which aws
(
    echo "sudo /usr/bin/s3fs ${bucket_name_mongodb} -o use_cache=/tmp -o allow_other -o uid=1001 -o mp_umask=002 -o multireq_max=5 -o nonempty /mys3bucket"
 echo "sudo chmod 777 /mys3bucket/"
 echo "/usr/bin/aws s3 cp s3://${bucket_name_mount_helper}/mongodb.${mongodb_version}.tar s3://${bucket_name_mongodb}/mongodb.${mongodb_version}.tar"
 echo "sudo service docker start"
 echo "sudo docker load -i /mys3bucket/mongodb.${mongodb_version}.tar"
 echo "sudo rm /mys3bucket/mongodb.${mongodb_version}.tar"
 echo "sudo docker volume create -d local -o type=none -o o=bind -o device=/mys3bucket scraper-mongodb-volume"
 echo "sudo docker run -d --name scraper-mongodb -p 27017:27017 -v scraper-mongodb-volume:/data mongo:${mongodb_version}"
 echo "sudo docker container start scraper-mongodb"
 echo "echo $(docker ps --format '{{.Names}}') > /mys3bucket/container.txt"
 echo "echo $(df -Th /mys3bucket | tail -n +2 |  awk '{ print $1, $2, $7 }') > /mys3bucket/mount.txt"
 ) | sudo tee -a /etc/rc.d/rc.local
sudo chmod +x /etc/rc.d/rc.local

# populate pictures to S3 bucket for pictures

# reboot to execute the mongodb bash commands and verify that the remount works properly
sudo reboot
