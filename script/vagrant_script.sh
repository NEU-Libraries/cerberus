#!/usr/bin/env bash

sudo yum install -y file-devel mysql libreoffice wgt apache ImageMagick-devel sqlite-devel npm

cd ~

curl -O https://fits.googlecode.com/files/fits-0.6.2.zip

unzip fits-0.6.2.zip

cd fits-0.6.2

chmod +x fits.sh

echo 'PATH=$PATH:$HOME/fits-0.6.2' >> ~/.bashrc 
echo 'export PATH'

source ~/.bashrc


wget http://download.redis.io/releases/redis-2.6.16.tar.gz
tar xzf redis-2.6.16.tar.gz
cd redis-2.6.16
make

sudo su
echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
sysctl vm.overcommit_memory=1

exit


echo 'PATH=$PATH:$HOME/redis-2.6.16/src' >> ~/.bashrc 
echo 'export PATH'


\curl -L https://get.rvm.io | bash -s stable --rails --ruby=2.0.0

source ~/.bashrc

cd /vagrant

gem install bundler

bundle install --verbose




