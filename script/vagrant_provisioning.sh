#!/usr/bin/env bash

/bin/bash --login

echo "Adding EPEL repository"
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

echo "Adding REMI repository"
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

echo "Enabling EPEL and REMI repositories"
sudo rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm
rm /home/vagrant/epel-release-6-8.noarch.rpm
rm /home/vagrant/remi-release-6.rpm

echo "Installing package dependencies"
sudo yum install file-devel-5.04-15.el6.x86_64 --assumeyes
sudo yum install file-libs-5.04-15.el6.x86_64 --assumeyes
sudo yum install sqlite-devel-3.6.20-1.el6.x86_64 --assumeyes
sudo yum install ghostscript-8.70-19.el6.x86_64 --assumeyes
sudo yum install ImageMagick-devel-6.5.4.7-7.el6_5.x86_64 --assumeyes
sudo yum install redis-2.4.10-1.el6.x86_64 --assumeyes
sudo yum install libreoffice-headless-4.0.4.2-9.el6.x86_64 --assumeyes
sudo yum install unzip-6.0-1.el6.x86_64 --assumeyes
sudo yum install zsh-4.3.10-7.el6.x86_64 --assumeyes
sudo yum install mysql-devel-5.1.73-3.el6_5.x86_64 --assumeyes
sudo yum install nodejs --assumeyes
sudo yum install htop --assumeyes

echo "Installing Git"
wget https://www.kernel.org/pub/software/scm/git/git-1.8.2.3.tar.gz
tar xzvf git-1.8.2.3.tar.gz
cd git-1.8.2.3
make prefix=/usr/local all
sudo make prefix=/usr/local install
cd /home/vagrant
rm git-1.8.2.3.tar.gz

echo "Making redis auto-start"
sudo chkconfig redis on

echo "Installing FITS"
cd /home/vagrant
curl -O https://fits.googlecode.com/files/fits-0.6.2.zip
unzip fits-0.6.2.zip
chmod +x /home/vagrant/fits-0.6.2/fits.sh
sudo mv /home/vagrant/fits-0.6.2 /opt/fits-0.6.2
echo 'PATH=$PATH:/opt/fits-0.6.2' >> /home/vagrant/.bashrc
echo 'export PATH'  >> /home/vagrant/.bashrc
source /home/vagrant/.bashrc

echo "Installing RVM"
cd /home/vagrant
\curl -sSL https://get.rvm.io | bash
source /home/vagrant/.profile
rvm pkg install libyaml
rvm install ruby-2.0.0-p451
rvm use ruby-2.0.0-p451
source /home/vagrant/.rvm/scripts/rvm

echo "Setting up DRS"
cd /home/vagrant/drs
gem install bundler
bundle install
rake db:migrate
rails g hydra:jetty
rake jetty:config
rake db:test:prepare
touch /home/vagrant/drs/.git/hooks/pre-push
echo '#!/bin/sh' >> /home/vagrant/drs/.git/hooks/pre-push
echo 'rake smoke_test' >> /home/vagrant/drs/.git/hooks/pre-push
chmod +x /home/vagrant/drs/.git/hooks/pre-push

echo "Starting Redis"
sudo service redis start

echo "Installing Oh-My-Zsh"
cd /home/vagrant
\curl -L http://install.ohmyz.sh | sh
sudo chsh -s /bin/zsh vagrant
