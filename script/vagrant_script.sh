#!/usr/bin/env bash


echo "Installing yum packages with sudo"
sudo yum install -y file-devel mysql wget apache ImageMagick-devel sqlite-devel npm zsh


### Become root
echo "Becoming root user and putting packagage in /opt directory"
sudo su

cd /opt

### Install fits
curl -O https://fits.googlecode.com/files/fits-0.6.2.zip
unzip fits-0.6.2.zip
cd fits-0.6.2
chmod +x fits.sh
echo 'PATH=$PATH:/opt/fits-0.6.2' >> /etc/bashrc 
echo 'export PATH'  >> /etc/bashrc 
source /etc/bashrc


echo "Installed fits.sh tool"


### Install redis
wget http://download.redis.io/releases/redis-2.6.16.tar.gz
tar xzf redis-2.6.16.tar.gz
cd redis-2.6.16
make


echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
sysctl vm.overcommit_memory=1

echo 'PATH=$PATH:/opt/redis-2.6.16/src' >> /etc/bashrc 
echo 'export PATH'  >> /etc/bashrc 

echo "Installed redis"



wget http://download.documentfoundation.org/libreoffice/stable/4.1.3/rpm/x86_64/LibreOffice_4.1.3_Linux_x86-64_rpm.tar.gz
tar xzf LibreOffice_4.1.3_Linux_x86-64_rpm.tar.gz
cd ./LibreOffice_4.1.3_Linux_x86-64_rpm/RPMS
yum -y localinstall  *.rpm


echo 'PATH=$PATH:/opt/libreoffice4.1/program' >> /etc/bashrc 
echo 'export PATH'  >> /etc/bashrc 

echo "Installed LibreOffice"


exit

### exit root

\curl -L https://get.rvm.io | bash -s stable --rails --ruby=2.0.0

source /etc/bashrc
source ~/.bashrc

cd /vagrant

gem install bundler

bundle install --verbose

rake db:migrate

rails g hydra:jetty

rake jetty:config

rake reset_data