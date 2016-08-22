#!/usr/bin/env bash

/bin/bash --login

sudo yum -y install https://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
sudo sed -i -e 's/^enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-Vault.repo

sudo sed -i -e 's,^ACTIVE_CONSOLES=.*$,ACTIVE_CONSOLES=/dev/tty1,' /etc/sysconfig/init

echo "Installing package dependencies"
# This is complete garbage. Yum is garbage. I hate both yum, and libreoffice.
# The shared library libswdlo.so that we need is in libreoffice-writer-4.0.4.2-9, but yum
# wants it from the updated package of ure and opensymbol, so you get in a circle of hell if you try
# to just install libreoffice-headless-4.0.4.2-9.

# Installing from the bottom up, in the most ass backwards way imaginable, allows
# for the correct version to prevail.

# The reason we need 4.0.4.2-9 is that the version after this silently fails when
# converting objects (which hydra-derivatives is trying to do). There are many bug
# reports for this issue, but no fixes that I can find that work reliably.
sudo yum install ImageMagick-devel-6.5.4.7-6.el6_2.x86_64 --assumeyes
sudo yum install libreoffice-ure-4.0.4.2-9.el6.x86_64 --assumeyes
sudo yum install libreoffice-writer-4.0.4.2-9.el6.x86_64 --assumeyes
sudo yum install libreoffice-headless-4.0.4.2-9.el6.x86_64 --assumeyes

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
rvm install ruby-2.0.0-p643
rvm use ruby-2.0.0-p643

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
rake db:migrate
rm -rf /home/vagrant/cerberus/jetty
rails g hydra:jetty
rake jetty:config
rake db:test:prepare
rm -f /home/vagrant/cerberus/.git/hooks/pre-push
touch /home/vagrant/cerberus/.git/hooks/pre-push
echo '#!/bin/sh' >> /home/vagrant/cerberus/.git/hooks/pre-push
echo 'rake smoke_test' >> /home/vagrant/cerberus/.git/hooks/pre-push
chmod +x /home/vagrant/cerberus/.git/hooks/pre-push

echo "Setting up Loris"
sudo yum groupinstall "Development tools" --assumeyes
sudo yum install zlib-devel bzip2-devl openssl-devel ncurses-devel \
    sqlite-devel readline-devel tk-devel --assumeyes
sudo wget http://python.org/ftp/python/2.7.3/Python-2.7.3.tar.bz2
sudo tar xf Python-2.7.3.tar.bz2
sudo cd Python-2.7.3
sudo ./configure --prefix=/usr/local --enable-shared
sudo make && make altinstall
sudo echo "/usr/local/lib/python2.7" > /etc/ld.so.conf.d/python27.conf
sudo echo "/usr/local/lib" >> /etc/ld.so.conf.d/python27.conf
sudo ldconfig
sudo wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py
sudo /usr/local/bin/python2.7 get-pip.py
sudo yum install httpd-devel --assumeyes

# sudo ./configure --with-python=/usr/local/bin/python2.7
# sudo make && make install
#python should be at /usr/local/bin/python
#pip should be at /usr/local/bin/pip

wget http://modwsgi.googlecode.com/files/mod_wsgi-3.4.tar.gz
tar -zxf mod_wsgi-3.4.tar.gz
cd mod_wsgi-3.4
./configure --with-python=/usr/local/bin/python2.7
make && make install

sudo yum install libjpeg-turbo libjpeg-turbo-devel \
    freetype freetype-devel \
    zlib-devel \
    libtiff-devel
sudo wget https://github.com/ksclarke/freelib-djatoka/tree/master/lib/Linux-x86-64/libkdu_v60R.so
sudo wget https://github.com/ksclarke/freelib-djatoka/tree/master/lib/Linux-x86-64/kdu_expand
sudo mv libkdu_v60R.so /usr/local/lib
sudo mv kdu_expand /usr/local/bin
sudo export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
sudo /usr/local/bin/pip2.7 install Werkzeug

useradd -d /var/www/loris -s /sbin/false loris
cd /opt
git clone https://github.com/pulibrary/loris.git
cd loris
sudo /usr/local/bin/pip uninstall PIL
sudo /usr/local/bin/pip uninstall Pillow
sudo /usr/local/bin/pip uninstall configobj
sudo /usr/local/bin/pip uninstall requests
sudo /usr/local/bin/pip uninstall mock
sudo /usr/local/bin/pip uninstall responses
sudo /usr/local/bin/pip install Pillow
sudo /usr/local/bin/pip install configobj
sudo /usr/local/bin/pip install requests
sudo /usr/local/bin/pip install mock
sudo /usr/local/bin/pip install responses

# (configure as necessary)
cd /opt/loris
/usr/local/bin/python2.7 setup.py install

# set up conf in /etc/httpd/conf.d/loris.conf
sh -c "cat >/etc/httpd/conf.d/loris.conf" <<'EOF'
ExpiresActive On
ExpiresDefault "access plus 5184000 seconds"
AllowEncodedSlashes On
LoadModule wsgi_module modules/mod_wsgi.so
WSGIDaemonProcess loris2 user=loris group=loris processes=10 threads=15 maximum-requests=10000
WSGIScriptAlias /loris /var/www/loris2/loris2.wsgi
WSGIProcessGroup loris2
WSGISocketPrefix /var/run/wsgi
EOF
