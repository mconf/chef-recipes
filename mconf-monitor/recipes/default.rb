# Cookbook Name:: mconf-monitor
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

%w{ "zlib1g-dev" "git-core" "python-dev" "python-argparse" "subversion" "libmcrypt4" }.each do |pkg|
  package pkg do
    action :install
  end
end

include_recipe "psutil"

if File.exists?("/usr/local/bin/bbb-conf") and node[:mconf][:instance_type] == "bigbluebutton"
  node.set[:mconf][:hostname] = `bbb-conf --salt | grep 'URL' | tr -d ' ' | sed 's:URL\\:http\\://\\([^:/]*\\).*:\\1:g'`.chop
  node.set[:mconf][:bbb_url] =  `bbb-conf --salt | grep 'URL' | tr -d ' ' | sed 's/URL://g'`.chop
  node.set[:mconf][:bbb_salt] = `bbb-conf --salt | grep 'Salt' | tr -d ' ' | sed 's/Salt://g'`.chop
elsif node[:mconf][:instance_type] == "nagios"
  node.set[:mconf][:hostname] = "localhost"
else
  node.set[:mconf][:hostname] = node[:ipaddress]
end

if node[:mconf][:instance_type] == "bigbluebutton"
  node.set[:mconf][:nagios_message] = "#{node[:mconf][:instance_type]} #{node[:mconf][:bbb_url]} #{node[:mconf][:bbb_salt]}"
else
  node.set[:mconf][:nagios_message] = "#{node[:mconf][:instance_type]}"
end

directory "#{node[:mconf][:nagios][:dir]}" do
  mode "0775"
  owner "mconf"
  recursive true
end

#create script files
%w{ performance_report.py check_bbb_salt.sh daemon.py server_up.sh update.sh }.each do |file|
    template "#{node[:mconf][:nagios][:dir]}/#{file}" do
      source file
      mode 0755
      owner "mconf"
      action :create
    end
end

#get nsca file from server and call build script if there is a new file
remote_file "#{node[:mconf][:nagios][:dir]}/nsca-#{node[:nsca][:version]}.tar.gz" do
    source "http://prdownloads.sourceforge.net/sourceforge/nagios/nsca-#{node[:nsca][:version]}.tar.gz"
    mode "0644"
    notifies :run, 'script[nsca_build]', :immediately
end

#build nsca and call installer
script "nsca_build" do
    action :nothing
    interpreter "bash"
    user "root"
    cwd "#{node[:mconf][:nagios][:dir]}"
    code <<-EOH
        tar xzf "nsca-#{node[:nsca][:version]}.tar.gz"
        cd "nsca-#{node[:nsca][:version]}"
        ./configure
        make
        make install
    EOH
    notifies :run, 'script[install_nsca]', :immediately
end

#nsca install procedure 
script "install_nsca" do
    action :nothing
    interpreter "bash"
    user "root"
    cwd "#{node[:mconf][:nagios][:dir]}/nsca-#{node[:nsca][:version]}"
    code <<-EOH
        mkdir -p #{node[:nsca][:dir]} #{node[:nsca][:config_dir]}
        chown nagios:nagios -R /usr/local/nagios
        cp src/send_nsca #{node[:nsca][:dir]}
        cp sample-config/send_nsca.cfg #{node[:nsca][:config_dir]}/
        chmod a+r #{node[:nsca][:config_dir]}/send_nsca.cfg
    EOH
end

#performance reporter service definition
service "performance_report" do
    provider Chef::Provider::Service::Upstart
    subscribes :restart, resources()
    supports :restart => true, :start => true, :stop => true
end

#performance reporter template creation
template "performance_report upstart" do
    path "/etc/init/performance_report.conf"
    source "performance_report.conf"
    mode "0644"
    notifies :restart, resources(:service => "performance_report")
end

=begin
#add cron job to monitor bbb salt on bbb nodes
cron "bbb_salt_monitor" do
    minute "5"
    command "/var/mconf/tools/nagios/check_bbb_salt.sh 2>&1 >> #{node[:mconf][:log][:path]}/output_check_bbb_salt.txt"
    only_if do 
        "#{node[:mconf][:instance_type]}" == "bigbluebutton" 
    end
end

#send a "server up" signal to the nagios server on a freeswitch node
execute "freeswitch_server_up" do
    command "/var/mconf/tools/nagios/server_up.sh #{node[:mconf][:nagios_address]} #{node[:mconf][:instance_type]}"
    only_if do "#{node[:mconf][:instance_type]}" == "freeswitch" end
=end

execute "server up" do
  command "/usr/bin/printf \"%s\t%s\t%s\t%s\n\" \"localhost\" \"Server UP\" \"3\" \"#{node[:mconf][:nagios_message]}\" | #{node[:nsca][:dir]}/send_nsca -H #{node[:mconf][:nagios_address]} -c #{node[:nsca][:config_dir]}/send_nsca.cfg"
end
