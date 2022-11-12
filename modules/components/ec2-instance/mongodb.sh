#!/bin/bash

sudo yum update all
sudo yum update -y
# need at least docker openssl git
sudo yum install automake fuse fuse-devel gcc-c++ git libcurl-devel libxml2-devel make openssl-devel docker -y
sudo amazon-linux-extras install epel -y
sudo yum install s3fs-fuse -y

echo ${aws_access_key}:${aws_secret_key} > ${HOME}/.passwd-s3fs
chmod 600 ${HOME}/.passwd-s3fs

sudo mkdir /mys3bucket
sudo s3fs ${bucket_name_mongodb} -o passwd_file=${HOME}/.passwd-s3fs -o use_cache=/tmp -o allow_other -o uid=${UID} -o mp_umask=002 -o multireq_max=5 -o nonempty /mys3bucket
echo $(df -Th /mys3bucket | tail -n +2 |  awk '{ print $1, $2, $7 }') > /mys3bucket/_mount.txt

sudo service docker start
sudo docker volume create -d local -o type=none -o o=bind -o device=/mys3bucket scraper-mongodb-volume
sudo docker run -d --name scraper-mongodb -p 27017:27017 -v scraper-mongodb-volume:/data mongo:${mongodb_version}
sudo docker container start scraper-mongodb
echo $(sudo docker ps --format '{{.Names}}') > /mys3bucket/_container.txt

# script file for remounting
# replace non-default bash shortcuts with their directory location, found with `which s3fs`
sudo tee -a /etc/rc.d/rc.local > /dev/null <<EOT
echo ${aws_access_key}:${aws_secret_key} > ${HOME}/.passwd-s3fs
chmod 600 ${HOME}/.passwd-s3fs

sudo mkdir /mys3bucket
sudo /usr/bin/s3fs ${bucket_name_mongodb} -o passwd_file=${HOME}/.passwd-s3fs -o use_cache=/tmp -o allow_other -o uid=${UID} -o mp_umask=002 -o multireq_max=5 -o nonempty /mys3bucket
echo $(df -Th /mys3bucket | tail -n +2 |  awk '{ print $1, $2, $7 }') > /mys3bucket/_mount.txt

sudo service docker start
sudo docker volume create -d local -o type=none -o o=bind -o device=/mys3bucket scraper-mongodb-volume
sudo docker run -d --name scraper-mongodb -p 27017:27017 -v scraper-mongodb-volume:/data mongo:${mongodb_version}
sudo docker container start scraper-mongodb
echo $(sudo docker ps --format '{{.Names}}') > /mys3bucket/_container.txt
EOT
sudo chmod +x /etc/rc.d/rc.local

# TODO: populate pictures to S3 bucket for pictures

