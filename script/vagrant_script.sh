#!/usr/bin/env bash


echo "Installing yum packages with sudo"

sudo yum install -y file-devel mysql wget apache ImageMagick-devel sqlite-devel npm zsh java zlib-devel openssl-devel cpio expat-devel gettext-devel curl-devel perl-ExtUtils-CBuilder perl-ExtUtils-MakeMaker gitflow



### Become root
echo "Becoming root user and putting packagage in /opt directory"
sudo su

cd /opt

### Install fits
curl -O https://fits.googlecode.com/files/fits-0.6.2.zip
unzip fits-0.6.2.zip
mv fits-0.6.2 fits

cd fits
chmod +x fits.sh
echo 'PATH=$PATH:/opt/fits' >> /etc/bashrc 
echo 'export PATH'  >> /etc/bashrc 
source /etc/bashrc


echo "Installed fits.sh tool"


### Install redis
cd /opt
wget http://download.redis.io/releases/redis-2.6.16.tar.gz
tar xzf redis-2.6.16.tar.gz
mv redis-2.6.16 redis
cd redis
make


echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
sysctl vm.overcommit_memory=1

echo 'PATH=$PATH:/opt/redis/src' >> /etc/bashrc 
echo 'export PATH'  >> /etc/bashrc 

echo "Installed redis"


## Install LibreOffice
cd /opt
wget http://download.documentfoundation.org/libreoffice/stable/4.1.3/rpm/x86_64/LibreOffice_4.1.3_Linux_x86-64_rpm.tar.gz
tar xzf LibreOffice_4.1.3_Linux_x86-64_rpm.tar.gz
cd ./LibreOffice_4.1.3.2_Linux_x86-64_rpm/RPMS
yum -y localinstall  *.rpm


echo 'PATH=$PATH:/opt/libreoffice4.1/program' >> /etc/bashrc 
echo 'export PATH'  >> /etc/bashrc 

echo "Installed LibreOffice"



### Install RVM, Ruby and Rails
cd /opt

\curl -L https://get.rvm.io | bash -s stable --rails --ruby=2.0.0



source /etc/bashrc
source ~/.bashrc

echo "Installed RVM Ruby and Rails"

sudo su vagrant
cd /vagrant


gem install bundler

bundle install

rake db:migrate

rails g hydra:jetty

rake jetty:config

rake reset_data


echo "Install Git"
cd /opt

sudo su
yum -y install 

wget https://github.com/git/git/archive/v1.8.4.3.tar.gz
tar -xzvf ./v1.8.4.3
cd git-1.8.4.3/
make prefix=/usr/local all
make prefix=/usr/local install







