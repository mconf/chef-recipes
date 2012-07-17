# Cookbook Name:: mconf-monitor
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

package "zlib1g-dev"
package "git-core"
package "python-dev"
package "python-argparse"
package "subversion"

include_recipe "psutil"

directory "/var/mconf/tools/nagios/" do
  mode "0775"
  owner "mconf"
  recursive true
end

#create script files
%w{ performance_report.py check_bbb_salt.sh daemon.py server_up.sh update.sh}.each do |file|
    template "/var/mconf/tools/nagios/#{file}" do
      source file
      mode 0755
      owner "mconf"
      action :create_if_missing
    end
end

#get nsca file from server and call build script if there is a new file
remote_file "/var/mconf/tools/nagios/nsca-#{node[:mconf][:ncsa_version]}.tar.gz" do
    source "http://prdownloads.sourceforge.net/sourceforge/nagios/nsca-#{node[:mconf][:ncsa_version]}.tar.gz"
    mode "0644"
    notifies :run, 'script[nsca_build]', :immediately
end

#build nsca and call installer
script "nsca_build" do
    action :nothing
    interpreter "bash"
    user "root"
    cwd "/var/mconf/tools/nagios/"
    code <<-EOH
        tar xzf "nsca-#{node[:mconf][:ncsa_version]}.tar.gz"
        cd "nsca-#{node[:mconf][:ncsa_version]}"
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
    cwd "/var/mconf/tools/nagios/nsca-#{node[:mconf][:ncsa_version]}"
    code <<-EOH
    if [ #{node[:mconf][:instance_type]} == "nagios" ]
    then
        cp src/nsca /usr/local/nagios/bin/
        cp sample-config/nsca.cfg /usr/local/nagios/etc/
        chmod a+r /usr/local/nagios/etc/nsca.cfg
        # install as XINETD service
        cp /var/mconf/tools/nagios/$NSCA/sample-config/nsca.xinetd /etc/xinetd.d/nsca
        sed -i "s:\tonly_from.*:#\0:g" /etc/xinetd.d/nsca
        chmod a+r /etc/xinetd.d/nsca
        service xinetd restart
    else
        mkdir -p /usr/local/nagios/bin/ /usr/local/nagios/etc/
        chown nagios:nagios -R /usr/local/nagios
    fi

    cp src/send_nsca /usr/local/nagios/bin/
    cp sample-config/send_nsca.cfg /usr/local/nagios/etc/
    chmod a+r /usr/local/nagios/etc/send_nsca.cfg
    EOH
end

#performance reporter service definition
service "performance_reporter" do
    provider Chef::Provider::Service::Upstart
    subscribes :restart, resources()
    supports :restart => true, :start => true, :stop => true
end

#performance reporter tamplate creation
template "performance_report.py" do
    path "/etc/init/performance_report.conf"
    source "performance_report.conf"
    mode "0644"
    notifies :restart, resources(:service => "performance_reporter")
end

#add cron job to monitor bbb salt on bbb nodes
cron "bbb_salt_monitor" do
    minute "5"
    command "/var/mconf/tools/nagios/check_bbb_salt.sh 2>&1 >> /var/mconf/log/output_check_bbb_salt.txt "
    only_if do 
        "#{node[:mconf][:instance_type]}" == "bigbluebutton" 
    end
end

#send a "server up" signal to the nagios server on a freeswitch node
execute "freeswitch_server_up" do
    command "/var/mconf/tools/nagios/server_up.sh #{node[:mconf][:nagios_address]} #{node[:mconf][:instance_type]}"
    only_if do "#{node[:mconf][:instance_type]}" == "freeswitch" end
end
