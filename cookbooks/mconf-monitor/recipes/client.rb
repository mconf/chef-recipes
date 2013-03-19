#
# Cookbook Name:: mconf-monitor
# Recipe:: client
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

# if node[:mconf][:monitor][:servers] is set, it will use it, otherwise it 
# will use the nsca servers from nsca_handler
if node[:mconf][:monitor][:servers]
  monitoring_servers = node[:mconf][:monitor][:servers]
else
  monitoring_servers = node[:nsca_handler][:nsca_server]
end

include_recipe "nsca"
include_recipe "psutil"

%w{ git-core python-dev python-argparse subversion }.each do |pkg|
  package pkg do
    action :install
  end
end

include_recipe "bigbluebutton::load-properties"

t = ruby_block "set nsca properties" do
    block do
        if node[:mconf][:instance_type] == "bigbluebutton"
            node.set[:nsca][:hostname] = node[:bbb][:server_domain]
        elsif node[:mconf][:instance_type] == "nagios"
            node.set[:nsca][:hostname] = "localhost"
        else
            node.set[:nsca][:hostname] = node[:ipaddress]
        end
    end
end
t.run_action(:create)

directory node[:mconf][:nagios][:dir] do
  owner node[:mconf][:user]
  recursive true
end

# performance reporter template creation
template "performance_report upstart" do
    path "/etc/init/performance_report.conf"
    source "performance_report.conf.erb"
    mode "0644"
    if monitoring_servers and not monitoring_servers.empty?
      notifies :restart, "service[performance_report]", :delayed
    end
end

template "#{node[:mconf][:nagios][:dir]}/reporter.sh" do
    source "reporter.sh.erb"
    mode 0755
    owner node[:mconf][:user]
    variables({
      :nsca_server => monitoring_servers,
      :nsca_dir => node[:nsca][:dir],
      :nsca_config_dir => node[:nsca][:config_dir],
      :nsca_timeout => node[:nsca][:timeout]
    })
    action :create
    if monitoring_servers and not monitoring_servers.empty?
      notifies :restart, "service[performance_report]", :delayed
    end
end

cookbook_file "#{node[:mconf][:nagios][:dir]}/performance_report.py" do
    source "performance_report.py"
    mode 0755
    owner node[:mconf][:user]
    action :create
    if monitoring_servers and not monitoring_servers.empty?
      notifies :restart, "service[performance_report]", :delayed
    end
end

# performance reporter service definition
service "performance_report" do
    provider Chef::Provider::Service::Upstart
    supports :restart => true, :start => true, :stop => true
    # :restart isn't enough to reload the new template, and :reload 
    # duplicates the process
    restart_command "stop performance_report && start performance_report"
    if monitoring_servers and not monitoring_servers.empty?
      if node[:mconf][:monitor][:force_restart]
        action [ :enable, :restart ]
        node[:mconf][:monitor][:force_restart] = false
      else
        action [ :enable, :start ]
      end
    else
      action [ :disable, :stop ]
    end
end
