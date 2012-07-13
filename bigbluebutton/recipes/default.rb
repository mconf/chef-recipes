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
    File.exists?('/etc/apt/sources.list.d/ubuntu-source.list')
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
    File.exists?('/etc/apt/sources.list.d/bigbluebutton-source.list')
  end
end

execute "refresh apt" do
  user "root"
  command "apt-get update"
  ignore_failure true
  action :run
end

package "bigbluebutton" do
  # we won't use the version for bigbluebutton and bbb-demo because they
  # don't keep the older versions
#  version node[:bigbluebutton][:version]
  response_file "bigbluebutton.seed"
  action :install
  # well, it just doesn't work, can't be done
#  notifies :run, resources(:execute => "apt-get update"), :immediately
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

