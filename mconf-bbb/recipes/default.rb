# Cookbook Name:: mconf-bbb
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

include_recipe "ruby-1.9.2"

# add ubuntu repo
apt_repository "ubuntu-us" do
  uri "http://archive.ubuntu.com/ubuntu/"
  components ["lucid" , "multiverse"]
end

# add bigbluebutton repo
apt_repository "bigbluebutton" do
  key "http://ubuntu.bigbluebutton.org/bigbluebutton.asc"
  uri "http://ubuntu.bigbluebutton.org/lucid_dev_08"
  components ["bigbluebutton-lucid" , "main"]
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
