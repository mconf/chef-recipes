#
# Cookbook Name:: live-notes-server
# Recipe:: default
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

%w{ openjdk-6-jdk git-core }.each do |pkg|
  package pkg do
    action :install
  end
end

[ node[:notes][:xsbt][:dir],
  node[:notes][:notes_server][:dir] ].each do |dir|
  directory dir do
    recursive true
    owner node[:mconf][:user]
    action :create
  end
end

git node[:notes][:xsbt][:dir] do
  repository "git://github.com/harrah/xsbt.git"
  reference "v#{node[:notes][:xsbt][:version]}"
  user node[:mconf][:user]
  action :sync
end

remote_file "/usr/local/bin/sbt-launch.jar" do
  source node[:notes][:sbt_launch][:url]
  checksum node[:notes][:sbt_launch][:checksum]
  owner node[:mconf][:user]
  mode "0644"
  action :create_if_missing
end

cookbook_file "/usr/local/bin/sbt" do
    source "sbt"
    owner node[:mconf][:user]
    mode "0755"
end

{ "live-notes-server.erb" => "/usr/local/bin/live-notes-server" }.each do |k,v|
    template v do
        source k
        owner node[:mconf][:user]
        mode "0755"
    end
end

git node[:notes][:notes_server][:dir] do
  repository "git://github.com/mconf/live-notes-server.git"
  reference "master"
  user node[:mconf][:user]
  action :sync
end

template "live-notes-server upstart" do
  path "/etc/init/live-notes-server.conf"
  source "live-notes-server.conf.erb"
  mode "0644"
  notifies :restart, "service[live-notes-server]", :delayed
end

service "live-notes-server" do
  provider Chef::Provider::Service::Upstart
  supports :restart => true, :start => true, :stop => true
  # since mconf-live0.3.4, the live-notes-server isn't used anymore
  # action [ :enable, :start ]
  action [ :stop, :disable ]
  subscribes :restart, resources()
end

