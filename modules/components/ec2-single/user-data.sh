#!/bin/bash

yum update all
apt-get update
sudo apt-get install automake autotools-dev fuse g++ git libcurl4-gnutls-dev libfuse-dev libssl-dev libxml2-dev make pkg-config

git clone https://github.com/s3fs-fuse/s3fs-fuse.git