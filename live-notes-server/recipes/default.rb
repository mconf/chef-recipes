# Cookbook Name:: live-notes-server
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

%w{ "openjdk-6-jdk" "git-core"}.each do |pkg|
  package pkg do
    action :install
  end
end

[ "#{node[:mconf][:tools][:path]}",
  "#{node[:mconf][:log][:path]}",
  "#{node[:notes][:xsbt][:path]}",
  "#{node[:notes][:notes_server][:path]}" ].each do |dir|
  directory dir do
    recursive true
    owner "mconf"
    group "mconf"
    action :create
  end
end

git "#{node[:notes][:xsbt][:path]}" do
  repository "git://github.com/harrah/xsbt.git"
  reference "v#{node[:notes][:xsbt][:version]}"
  user "mconf"
  group "mconf"
  action :sync
end

remote_file "/usr/local/bin/sbt-launch.jar" do
  source "#{node[:notes][:sbt_launch][:url]}"
  owner "mconf"
  group "mconf"
  mode "0644"
end

cookbook_file "/usr/local/bin/sbt" do
  source "sbt"
  owner "mconf"
  group "mconf"
  mode "0755"
end

template "/usr/local/bin/live-notes-server" do
  source "live-notes-server"
  owner "mconf"
  group "mconf"
  mode "0755"
end

git "#{node[:notes][:notes_server][:path]}" do
  repository "git://github.com/mconf/live-notes-server.git"
  reference "master"
  user "mconf"
  group "mconf"
  action :sync
end

service "live-notes-server" do
  provider Chef::Provider::Service::Upstart
  subscribes :restart, resources()
  supports :restart => true, :start => true, :stop => true
end

template "live-notes-server upstart" do
  path "/etc/init/live-notes-server.conf"
  source "live-notes-server.conf"
  mode "0644"
  notifies :restart, resources(:service => "live-notes-server")
end

