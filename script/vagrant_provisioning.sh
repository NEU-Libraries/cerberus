#!/usr/bin/env bash

echo "Adding EPEL repository"
sudo wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

echo "Adding REMI repository"
sudo wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

echo "Enabling EPEL and REMI repositories"
sudo rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm

echo "Installing package dependencies"

sudo yum install file-libs.5.04-15 --assumeyes
sudo yum install sqlite-devel.3.6.20 --assumeyes
sudo yum install ghostscript.8.70 --assumeyes
sudo yum install ImageMagick.6.5.4.7 --assumeyes
sudo yum install redis.2.4.10 --assumeyes
