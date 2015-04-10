# -*- mode: ruby -*-
# vi: set ft=ruby :

# For now vagrant is only used to test recipes using chef-solo in an isolated VM.
# It could be used to install a test chef-server in the future.

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # Use Ubuntu 14.04 Trusty Tahr 64-bit as our operating system
  config.vm.box = 'ubuntu/trusty64'
  config.vm.provider 'lxc' do |v, override|
    override.vm.box = 'fgrehm/trusty64-lxc'
  end

  config.vm.box_download_insecure = true

  # config.vm.network :forwarded_port, guest: 3000, host: 3000

  chef_version = IO.read(File.join(File.dirname(__FILE__), '.chef-version')).chomp
  config.omnibus.chef_version = chef_version

  # Use Chef Solo to provision our virtual machine
  config.vm.provision :chef_solo do |chef|
    chef.cookbooks_path = ['vagrant/cookbooks']
    # chef.log_level = :debug

    chef.add_recipe 'apt'
    chef.add_recipe 'git'
    chef.add_recipe 'vim'
    chef.add_recipe 'ruby_build'
    chef.add_recipe 'rbenv::system'
    chef.add_recipe 'rbenv::vagrant'

    # Install ruby and gems
    # Set an empty root password for MySQL to make things simple
    rb_version = IO.read(File.join(File.dirname(__FILE__), '.ruby-version')).chomp
    chef.json = {
      rbenv: {
        rubies: [rb_version],
        global: rb_version,
        gems: {
          rb_version => [
            { name: 'bundler' },
            { name: 'chef', version: chef_version }
          ]
        }
      }
    }
  end
end
