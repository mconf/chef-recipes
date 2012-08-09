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
  # it definitely doesn't work
#  notifies :run, 'execute[apt-get update]', :immediately
end

execute "apt-get update" do
  user "root"
  action :run
end

ruby_block "restart-bigbluebutton" do
  block do
    node.set["restart_bigbluebutton"] = true
  end
  action :nothing
end

package "bigbluebutton" do
  # we won't use the version for bigbluebutton and bbb-demo because the BigBlueButton
  # folks don't keep the older versions
#  version node[:bigbluebutton][:version]
  response_file "bigbluebutton.seed"
  action :install
  notifies :create, "ruby_block[restart-bigbluebutton]", :immediately
end

package "bbb-demo" do
#  version node[:bbb_demo][:version]
  action :install
end

template "/usr/share/red5/webapps/deskshare/WEB-INF/red5-web.xml" do
  source "red5-web-deskshare.xml"
  mode "0644"
  variables(
    :record_deskshare => node[:bbb][:recording][:deskshare]
  )
  notifies :create, "ruby_block[restart-bigbluebutton]", :immediately
end

template "/usr/share/red5/webapps/video/WEB-INF/red5-web.xml" do
  source "red5-web-video.xml"
  mode "0644"
  variables(
    :record_video => node[:bbb][:recording][:video]
  )
  notifies :create, "ruby_block[restart-bigbluebutton]", :immediately
end

execute "restart" do
  user "root"
  command "bbb-conf --clean"
  only_if { node[:restart_bigbluebutton] }
end

ruby_block "remove-flag" do
  block do
    node.set["restart_bigbluebutton"] = false
  end
  action :create
end
