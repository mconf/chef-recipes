# Cookbook Name:: mconf-bbb
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

include_recipe "ruby-1.9.2"
include_recipe "apt"

# add ubuntu repo
apt_repository "ubuntu" do
  uri "http://archive.ubuntu.com/ubuntu/"
  components ["lucid" , "multiverse"]
  not_if do
    File.exists?('/etc/apt/sources.list.d/ubuntu-us-source.list')
  end
end

# create the cache directory
directory "#{Chef::Config[:file_cache_path]}" do
  recursive true
  action :create
end

# add bigbluebutton repo
apt_repository "bigbluebutton" do
  key "http://ubuntu.bigbluebutton.org/bigbluebutton.asc"
  uri "http://ubuntu.bigbluebutton.org/lucid_dev_08"
  components ["bigbluebutton-lucid" , "main"]
  not_if do
    File.exists?('/etc/apt/sources.list.d/bigbluebutton.list')
  end
end

# \TODO check how to do it using the apt recipe
execute "refresh apt" do
  command "apt-get update"
end

package "bigbluebutton" do
#  notifies :run, resources(:execute => "apt-get update"), :immediately
#  version node[:bigbluebutton][:version]
  response_file "bigbluebutton.seed"
  action :install
end

package "bbb-demo" do
#  version node[:bbb_demo][:version]
  action :install
end

execute "restart-bigbluebutton" do
  user "root"
  command "bbb-conf --clean"
  action :run
end

