# Cookbook Name:: mconf-bbb
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

include_recipe "ruby-1.9.2"

# add ubuntu repo
apt_repository "ubuntu" do
  uri "http://archive.ubuntu.com/ubuntu/"
  components ["lucid" , "multiverse"]
end

# create the cache directory
directory "#{Chef::Config[:file_cache_path]}" do
  action :create
end

# add bigbluebutton repo
apt_repository "bigbluebutton" do
  key "http://ubuntu.bigbluebutton.org/bigbluebutton.asc"
  uri "http://ubuntu.bigbluebutton.org/lucid_dev_08"
  components ["bigbluebutton-lucid" , "main"]
end

# \TODO check how to do it using the apt recipe
execute "update apt" do
  command "apt-get update"
end

# install bigbluebutton packages
%w{ bigbluebutton bbb-demo }.each do |pkg|
  package pkg do
    action :install
  end
end

execute "restart-bigbluebutton" do
  command "bbb-conf --clean"
  action :run
end
