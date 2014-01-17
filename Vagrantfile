# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "vagrant-centos"

  config.vm.box_url = "https://github.com/2creatives/vagrant-centos/releases/download/v0.1.0/centos64-x86_64-20131030.box"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  
  # Rails web brick runs on this server
  config.vm.network :forwarded_port, guest: 3000, host: 3000
  
  # Live Reload runs on this server
  config.vm.network :forwarded_port, guest: 35729, host: 35729

  config.vm.network :forwarded_port, guest: 8983, host: 8983

  # Forward the Jasmine interface on this port
  config.vm.network :forwarded_port, guest: 8888, host: 8888

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network :private_network, ip: "192.168.1.44"

  # If true, then any SSH connections made will enable agent forwarding.
  # Default value: false
  config.ssh.forward_agent = true
  
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", '5734']
    vb.customize ["modifyvm", :id, "--ioapic", 'on']
    vb.customize ["modifyvm", :id, "--cpus", '6']
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "off"]

  end
  config.vm.provider "vmware_fusion" do |v, override|

  end

  config.vm.provision "shell", path: "script/vagrant_script.sh"
  config.vm.synced_folder ".", "/vagrant", nfs: true

end
