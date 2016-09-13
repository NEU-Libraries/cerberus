# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# Sets vmware fusion as the default provider
VAGRANT_DEFAULT_PROVIDER = "virtualbox"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # Every Vagrant virtual environment requires a box to build off of.
  # This will have to be downloaded. We're making our own images now.
  config.vm.box = "chef/centos-6.6"

  # Forward default rails development server port
  config.vm.network :forwarded_port, guest: 3000, host: 3000

  # Live Reload runs on this server
  config.vm.network :forwarded_port, guest: 35729, host: 35729

  # Forward local fedora/solr instances on this port
  config.vm.network :forwarded_port, guest: 8983, host: 8983

  # Forward the Jasmine interface on this port
  config.vm.network :forwarded_port, guest: 8888, host: 8888

  # If true, then any SSH connections made will enable agent forwarding.
  # Default value: false
  config.ssh.forward_agent = true

  # Optimizations for vmware_fusion machines
  config.vm.provider "vmware_fusion" do |vm|
    vm.customize ['modifyvm', :id, '--memory', '3072', '--cpus', '4', '--natdnsproxy1', 'off', '--natdnshostresolver1', 'off', '--ioapic', 'on']
    vm.vmx["memsize"] = "3072"
    vm.vmx["numvcpus"] = "4"
  end

  # Some optimization configurations kept in if someone needs to run Virtualbox
  # TODO: Figure out which of these are worth carrying over to the vmware config
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", '3072']
    vb.customize ["modifyvm", :id, "--ioapic", 'on']
    vb.customize ["modifyvm", :id, "--cpus", '4']
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  config.vm.provision "shell", path: "script/vagrant_provisioning.sh", privileged: false

  # Share the current directory to /vagrant on the virtual machine
  config.vm.synced_folder "." , "/home/vagrant/cerberus", nfs: true
  config.vm.network "private_network", ip: "192.168.50.4"

  config.ssh.private_key_path = "~/.vagrant.d/insecure_private_key"
  config.ssh.insert_key = false
end
