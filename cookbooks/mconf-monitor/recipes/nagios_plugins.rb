#
# Cookbook Name:: mconf-monitor
# Recipe:: nagios_plugins
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

%w{ python-argparse }.each do |pkg|
  package pkg do
    action :install
  end
end

%w{ bigbluebutton
    nagios-check_sip-1.3 }.each do |dir|
  directory "#{node[:nagios][:plugin_dir]}/#{dir}" do
    owner node[:nagios][:user]
    group node[:nagios][:group]
    mode 00775
    action :create
  end
end

%w{ curl wget sed }.each do |pkg|
  package pkg
end

cookbook_file "#{node[:nagios][:plugin_dir]}/check_bbb_version" do
  source "check_bbb_version"
  owner node[:nagios][:user]
  group node[:nagios][:group]
  mode 00775
  action :create
end

%w{ bigbluebutton/bbb_api.py 
    bigbluebutton/bigbluebutton_info.py 
    bigbluebutton/get-bigbluebutton-info.py 
    nagios-check_sip-1.3/check_sip }.each do |file|
  cookbook_file "#{node[:nagios][:plugin_dir]}/#{file}" do
    source file
    owner node[:nagios][:user]
    group node[:nagios][:group]
    mode 00755
    action :create
  end
end
