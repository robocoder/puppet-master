# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
    config.vm.define :master do |master_config|

        master_config.vm.hostname = "puppet.local"
        master_config.vm.box = "precise64"
        master_config.vm.box_url = "http://files.vagrantup.com/precise64.box"

        master_config.vm.network :private_network, ip: "192.168.56.126"

        master_config.vm.provision :shell, :path => "puppet-master.sh"
    end
end
