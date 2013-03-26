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

file "/usr/sbin/nagios" do
  action :delete
  only_if do
    not ::File.exists?("/usr/lib/cgi-bin/nagios3/status-json.cgi") and
    not ::File.exists?("#{Chef::Config[:file_cache_path]}/nagios/cgi")
  end
  notifies :run, "bash[compile-nagios]", :immediately
end

cookbook_file "#{Chef::Config[:file_cache_path]}/nagios/cgi/status-json.c" do
  source "status-json.c"
  owner node[:nagios][:user]
  group node[:nagios][:group]
  mode 00664
  action :create_if_missing
  only_if { ::File.exists?("#{Chef::Config[:file_cache_path]}/nagios/cgi") }
end

cookbook_file "#{Chef::Config[:file_cache_path]}/nagios/cgi/status-json.patch" do
  source "status-json.patch"
  owner node[:nagios][:user]
  group node[:nagios][:group]
  mode 00664
  action :create_if_missing
  only_if { ::File.exists?("#{Chef::Config[:file_cache_path]}/nagios/cgi") }
end

bash "rebuild nagios" do
  cwd "#{Chef::Config[:file_cache_path]}/nagios/cgi"
  code <<-EOH
    patch Makefile < status-json.patch
    make all
    make install
  EOH
  action :run
  only_if { ::File.exists?("#{Chef::Config[:file_cache_path]}/nagios/cgi") }
  creates "/usr/lib/cgi-bin/nagios3/status-json.cgi"
end
