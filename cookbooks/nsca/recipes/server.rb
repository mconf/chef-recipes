#
# Cookbook Name:: nsca
# Recipe:: server
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

include_recipe "nsca::default"

package "xinetd" do
  action :install
end

service "xinetd"

template "#{node[:nsca][:config_dir]}/nsca.cfg" do
  source "nsca.cfg.erb"
  mode 00644
  variables(
    :pid_file => "#{node[:nagios][:run_dir]}/nsca.pid",
    :nsca_user => node[:nagios][:user],
    :nsca_group => node[:nagios][:group],
    :command_file => "#{node[:nagios][:state_dir]}/rw/nagios.cmd"
  )
  action :create
  notifies :restart, "service[xinetd]", :delayed
end

script "setup nsca as xinetd service" do
  interpreter "bash"
  user "root"
  cwd "/usr/local/src/nsca-#{node[:nsca][:version]}"
  code <<-EOH
    cp sample-config/nsca.xinetd /etc/xinetd.d/nsca
    sed -i "s:\tonly_from.*:#\0:g" /etc/xinetd.d/nsca
    chmod a+r /etc/xinetd.d/nsca
    service xinetd restart
  EOH
  creates "/etc/xinetd.d/nsca"
  action :run
end
