#
# Cookbook Name:: mconf-monitor
# Recipe:: nuttcp
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

cookbook_file "/usr/local/bin/nuttcp-7.2.1" do
  source "nuttcp-7.2.1"
  mode "0755"
  owner node[:mconf][:user]
end

template "nuttcp upstart" do
  path "/etc/init/nuttcp.conf"
  source "nuttcp.conf.erb"
  mode "0644"
  notifies :stop, "service[nuttcp]", :delayed
  notifies :start, "service[nuttcp]", :delayed
end

service "nuttcp" do
  provider Chef::Provider::Service::Upstart
  supports :start => true, :stop => true
  action [ :enable, :start ]
  subscribes :restart, resources()
end
