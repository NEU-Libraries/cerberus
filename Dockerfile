FROM centos:6.6
MAINTAINER David Cliff <d.cliff@neu.edu>
RUN yum -y install https://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
RUN sed -i -e 's/^enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-Vault.repo
RUN yum install java-1.6.0-openjdk java-1.6.0-openjdk-devel --assumeyes
RUN yum install ghostscript --assumeyes
RUN yum install ImageMagick-devel --assumeyes
RUN yum install file-devel --assumeyes
RUN yum install file-libs --assumeyes
RUN yum install sqlite-devel --assumeyes
RUN yum install redis --assumeyes
RUN yum install unzip --assumeyes
RUN yum install zsh --assumeyes
RUN yum install mysql-devel --assumeyes
RUN yum install mysql-server --assumeyes
RUN yum install nodejs --assumeyes
RUN yum install htop --assumeyes
RUN yum install -y patch libyaml-devel gcc-c++ readline-devel libffi-devel bzip2 libtool bison
RUN yum install gcc gettext-devel expat-devel curl-devel zlib-devel openssl-devel perl-ExtUtils-CBuilder perl-ExtUtils-MakeMaker --assumeyes
RUN yum install wget --assumeyes
RUN yum install fontpackages-filesystem --assumeyes
RUN yum install git --assumeyes
RUN yum install tar --assumeyes
RUN yum install libreoffice-writer-4.0.4.2-9.el6.x86_64 --assumeyes
RUN yum install libreoffice-headless-4.0.4.2-9.el6.x86_64 --assumeyes
RUN yum install sudo --assumeyes
RUN yum install python-setuptools --assumeyes
RUN easy_install supervisor

# Init mysql
RUN /usr/bin/mysql_install_db

# Updating sudoers
RUN echo 'drs ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

# Updating supervisord config
RUN echo_supervisord_conf > /etc/supervisord.conf
RUN sed -i "s/^nodaemon.*/nodaemon=true/" /etc/supervisord.conf

RUN echo '[program:mysqld]' >> /etc/supervisord.conf
RUN echo 'command=/usr/bin/pidproxy /var/run/mysqld/mysqld.pid /usr/bin/mysqld_safe' >> /etc/supervisord.conf

RUN echo '[program:redis]' >> /etc/supervisord.conf
RUN echo 'command=/usr/bin/pidproxy /var/run/redis/redis.pid /usr/sbin/redis-server /etc/redis.conf' >> /etc/supervisord.conf

RUN echo '[program:jetty]' >> /etc/supervisord.conf
RUN echo 'command=/usr/bin/pidproxy /home/drs/cerberus/tmp/pids/_home_drs_cerberus_jetty.pid /home/drs/.rvm/gems/ruby-2.0.0-p643/wrappers/rake jetty:start' >> /etc/supervisord.conf
RUN echo 'user=drs' >> /etc/supervisord.conf
RUN echo 'directory=/home/drs/cerberus' >> /etc/supervisord.conf

RUN echo '[program:rails]' >> /etc/supervisord.conf
RUN echo 'command=/usr/bin/pidproxy /home/drs/cerberus/tmp/pids/server.pid /home/drs/.rvm/gems/ruby-2.0.0-p643/wrappers/bundle exec rails server -d' >> /etc/supervisord.conf
RUN echo 'user=drs' >> /etc/supervisord.conf
RUN echo 'directory=/home/drs/cerberus' >> /etc/supervisord.conf

RUN echo '[program:resque]' >> /etc/supervisord.conf
RUN echo 'command=/usr/bin/pidproxy /home/drs/cerberus/tmp/pids/resque-pool.pid /home/drs/.rvm/gems/ruby-2.0.0-p643/wrappers/bundle exec resque-pool --daemon -p /home/drs/cerberus/tmp/pids/resque-pool.pid' >> /etc/supervisord.conf
RUN echo 'user=drs' >> /etc/supervisord.conf
RUN echo 'directory=/home/drs/cerberus' >> /etc/supervisord.conf

# Making drs user
RUN useradd -ms /bin/zsh drs
RUN chown -R drs:drs /home/drs
USER drs
ENV HOME /home/drs
WORKDIR /home/drs

# Installing RVM
RUN gpg2 --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
RUN /bin/bash -l -c "curl -sSL https://get.rvm.io | bash -s stable"
RUN /bin/bash -l -c "rvm pkg install libyaml"
RUN /bin/bash -l -c "rvm install ruby-2.0.0-p643"
RUN /bin/bash -l -c "rvm use ruby-2.0.0-p643"

# Installing FITS
RUN curl -O https://fits.googlecode.com/files/fits-0.6.2.zip
RUN unzip fits-0.6.2.zip
RUN chmod +x /home/drs/fits-0.6.2/fits.sh
RUN echo 'PATH=$PATH:/opt/fits-0.6.2' >> /home/drs/.bashrc
RUN echo 'export PATH'  >> /home/drs/.bashrc

# Installing Oh-My-Zsh
RUN \curl -Lk http://install.ohmyz.sh | sh

# Setting timezone for vm so embargo doesn't get confused
RUN echo 'export TZ=America/New_York' >> /home/drs/.zshrc
RUN echo 'export TZ=America/New_York' >> /home/drs/.bashrc
RUN echo 'source /home/drs/.profile' >> /home/drs/.zshrc

# Moving FITS
USER root
RUN mv /home/drs/fits-0.6.2 /opt/fits-0.6.2

# Adding from src
USER root
ADD / cerberus/
RUN chown -R drs:drs cerberus/

# Kludge for https://github.com/projecthydra/jettywrapper/issues/15
USER drs
RUN rm -rf /home/drs/cerberus/tmp/new-solr-schema.zip
RUN mkdir -p /home/drs/cerberus/tmp \
  && curl -L http://librarystaff.neu.edu/DRSzip/new-solr-schema.zip -o /home/drs/cerberus/tmp/new-solr-schema.zip \
  && unzip /home/drs/cerberus/tmp/new-solr-schema.zip -d /home/drs/cerberus \
  && mv /home/drs/cerberus/hydra-jetty-new-solr-schema /home/drs/cerberus/jetty

# Installing Cerberus
USER drs
RUN /bin/zsh -l -c "/home/drs/cerberus/script/cerberus_setup.sh"

# Run mysql, redis, and rails
USER root
CMD ["/usr/bin/supervisord"]
