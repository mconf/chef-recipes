#!/bin/bash

# install chef client v0.10.x on ubuntu server 10.04
echo "deb http://apt.opscode.com/ `lsb_release -cs`-0.10 main" | sudo tee /etc/apt/sources.list.d/opscode.list

sudo mkdir -p /etc/apt/trusted.gpg.d
gpg --keyserver keys.gnupg.net --recv-keys 83EF826A
gpg --export packages@opscode.com | sudo tee /etc/apt/trusted.gpg.d/opscode-keyring.gpg > /dev/null

sudo apt-get update
sudo apt-get install opscode-keyring -y --force-yes

# if a ruby version was previously installed, it's removed before install the chef-client
# this is because ruby 1.8.0 is a dependency of the package chef
sudo update-alternatives --remove ruby /usr/bin/ruby1.9.2
sudo dpkg -r ruby1.9.2

# install chef client via package passing the server url
echo "chef chef/chef_server_url string http://chef.mconf.org:4000" | sudo debconf-set-selections && sudo apt-get install chef -y
