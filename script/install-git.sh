#!/usr/bin/env bash


echo "Install Git"
cd /opt

sudo su
wget https://github.com/git/git/archive/v1.8.4.3.tar.gz
tar -xzvf ./v1.8.4.3
cd git-1.8.4.3/
make prefix=/usr/local all
make prefix=/usr/local install
