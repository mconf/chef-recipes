#
# Cookbook Name:: mconf-monitor
# Recipe:: json_interface
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

cookbook_file "#{Chef::Config[:file_cache_path]}/nagios/cgi/status-json.c" do
  source "status-json.c"
  owner node[:nagios][:user]
  group node[:nagios][:group]
  mode 00664
end

cookbook_file "#{Chef::Config[:file_cache_path]}/nagios/cgi/status-json.patch" do
  source "status-json.patch"
  owner node[:nagios][:user]
  group node[:nagios][:group]
  mode 00664
  notifies :run, "execute[patch Makefile]", :immediately
end

execute "patch Makefile" do
  cwd "#{Chef::Config[:file_cache_path]}/nagios/cgi"
  command "patch Makefile < status-json.patch"
  action :nothing
  notifies :run, "bash[rebuild nagios]", :immediately
end

bash "rebuild nagios" do
  cwd "#{Chef::Config[:file_cache_path]}/nagios/cgi"
  code <<-EOH
    make all
    make install
  EOH
  creates "/usr/lib/cgi-bin/nagios3/status-json.cgi"
end
