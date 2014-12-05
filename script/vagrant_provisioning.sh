#!/usr/bin/env bash

/bin/bash --login

echo "Installing Git"
wget https://www.kernel.org/pub/software/scm/git/git-1.8.2.3.tar.gz
tar xzvf git-1.8.2.3.tar.gz
cd /home/vagrant/git-1.8.2.3
make prefix=/usr/local all
sudo make prefix=/usr/local install
cd /home/vagrant
rm git-1.8.2.3.tar.gz
rm -rf /home/vagrant/git-1.8.2.3

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
\curl -sSL https://get.rvm.io | bash -s stable
source /home/vagrant/.profile
rvm pkg install libyaml
rvm install ruby-2.0.0-p481
rvm use ruby-2.0.0-p481
source /home/vagrant/.rvm/scripts/rvm

echo "Setting up Cerberus"
cd /home/vagrant/cerberus
gem install bundler
bundle install
rake db:migrate
rails g hydra:jetty
rake jetty:config
rake db:test:prepare
rm -f /home/vagrant/cerberus/.git/hooks/pre-push
touch /home/vagrant/cerberus/.git/hooks/pre-push
echo '#!/bin/sh' >> /home/vagrant/cerberus/.git/hooks/pre-push
echo 'rake smoke_test' >> /home/vagrant/cerberus/.git/hooks/pre-push
chmod +x /home/vagrant/cerberus/.git/hooks/pre-push

echo "Installing Oh-My-Zsh"
cd /home/vagrant
\curl -Lk http://install.ohmyz.sh | sh
sudo chsh -s /bin/zsh vagrant
