#!/usr/bin/env bash

/bin/bash --login

sudo yum -y install https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
sudo yum -y install http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm

echo "Installing package dependencies"

sudo yum install ImageMagick-devel --assumeyes
sudo yum install libreoffice-ure --assumeyes
sudo yum install libreoffice-writer --assumeyes
sudo yum install libreoffice-headless --assumeyes

sudo yum install java-1.6.0-openjdk java-1.6.0-openjdk-devel --assumeyes
sudo yum install ghostscript --assumeyes
sudo yum install file-devel --assumeyes
sudo yum install file-libs --assumeyes
sudo yum install sqlite-devel --assumeyes
sudo yum install redis --assumeyes
sudo yum install unzip --assumeyes
sudo yum install zsh --assumeyes
sudo yum install mysql-devel --assumeyes
sudo yum install mysql-server --assumeyes
sudo yum install nodejs --assumeyes
sudo yum install htop --assumeyes
sudo yum install libtool gcc gettext-devel expat-devel curl-devel zlib-devel openssl-devel perl-ExtUtils-CBuilder perl-ExtUtils-MakeMaker --assumeyes
sudo yum install wget --assumeyes
sudo yum install clamav clamav-devel --assumeyes
sudo yum install libxml-devel libxslt-devel --assumeyes
sudo yum install poppler-utils --assumeyes
sudo yum install gitflow --assumeyes

# We need httpd for /etc/mime.types
sudo yum install httpd --assumeyes

echo "Making redis auto-start"
sudo chkconfig redis on
sudo service redis start

echo "Making mysql auto-start"
sudo chkconfig mysqld on
sudo service mysqld start

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
curl -O http://librarystaff.neu.edu/fits/fits-0.6.2.zip
unzip fits-0.6.2.zip
chmod +x /home/vagrant/fits-0.6.2/fits.sh
sudo mv /home/vagrant/fits-0.6.2 /opt/fits-0.6.2
echo 'PATH=$PATH:/opt/fits-0.6.2' >> /home/vagrant/.bashrc
echo 'export PATH'  >> /home/vagrant/.bashrc
source /home/vagrant/.bashrc

echo "Installing exiftool"
cd /home/vagrant
wget http://www.sno.phy.queensu.ca/\~phil/exiftool/Image-ExifTool-9.94.tar.gz
tar -zxvf Image-ExifTool-9.94.tar.gz
sudo mv Image-ExifTool-9.94 /opt/exiftool
rm Image-ExifTool-9.94.tar.gz

echo "Setting up faux handles"
mysql -u root < /home/vagrant/cerberus/spec/fixtures/files/handlesMIN.sql

echo "Install newer File"
cd /home/vagrant
git clone https://github.com/file/file.git file
cd /home/vagrant/file && autoreconf -i
cd /home/vagrant/file && ./configure
cd /home/vagrant/file && make
cd /home/vagrant/file && sudo make install

echo "Installing Oh-My-Zsh"
cd /home/vagrant
\curl -Lk http://install.ohmyz.sh | sh
sudo chsh -s /bin/zsh vagrant

echo "Installing RVM"
cd /home/vagrant
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
\curl -sSL https://get.rvm.io | bash -s stable --autolibs=enabled
source /home/vagrant/.rvm/scripts/rvm
rvm install ruby-2.3.3
rvm use ruby-2.3.3

echo "Setting timezone for vm so embargo doesn't get confused"
echo 'export TZ=America/New_York' >> /home/vagrant/.zshrc
echo 'export TZ=America/New_York' >> /home/vagrant/.bashrc

echo "Updating ClamAV"
sudo freshclam

echo "Setting up Cerberus"
cd /home/vagrant/cerberus
gem install bundler
bundle config build.nokogiri --use-system-libraries
bundle install --retry 5
rails db:migrate
rm -rf /home/vagrant/cerberus/tmp
rails db:test:prepare
