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

#set up nsca sender
script "nsca_build" do
        interpreter "bash"
        user "root"
        cwd "/var/mconf/tools/nagios/"
        not_if do File.exists?("/var/mconf/tools/nagios/nsca-#{node[:mconf][:ncsa_version]}.tar.gz") end
        code <<-EOH
            NSCA="nsca-#{node[:mconf][:ncsa_version]}"
            NSCA_TAR="$NSCA.tar.gz"
            wget -nc http://prdownloads.sourceforge.net/sourceforge/nagios/$NSCA_TAR
            tar xzf $NSCA_TAR
            cd $NSCA
            ./configure
            make
            make install
      EOH
      notifies :run, 'script[set_up_nsca_mode]', :immediately
end

script "set_up_nsca_mode" do
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
            USER=`whoami`
            chown $USER:$USER -R /usr/local/nagios
        fi

        cp src/send_nsca /usr/local/nagios/bin/
        cp sample-config/send_nsca.cfg /usr/local/nagios/etc/
        chmod a+r /usr/local/nagios/etc/send_nsca.cfg
        EOH
end

service "performance_reporter" do
    provider Chef::Provider::Service::Upstart
    subscribes :restart, resources()
    supports :restart => true, :start => true, :stop => true
end

template "performance_report.py" do
    path "/etc/init/performance_report.conf"
    source "performance_report.conf"
    mode "0644"
    notifies :restart, resources(:service => "performance_reporter")
end

#make monitor install
script "install_monitor" do
        interpreter "bash"
        user "mconf"
        cwd "/home/mconf/"
        code <<-EOH
            INSTANCE_TYPE=#{node[:mconf][:instance_type]}
            NAGIOS_ADDRESS=#{node[:mconf][:nagios_address]}
            INTERVAL=#{node[:mconf][:interval]}

            if [ $INSTANCE_TYPE != "nagios" ]
            then
                echo "Sending the Nagios packet to start monitoring"
                if [ $INSTANCE_TYPE == "bigbluebutton" ]
                then
                    CMD="/var/mconf/tools/nagios/check_bbb_salt.sh $NAGIOS_ADDRESS $INTERVAL | tee /var/mconf/log/output_check_bbb_salt.txt 2>&1"
                    eval $CMD
                    # add a cron job to check if there's any modification on the BigBlueButton URL or salt
                    crontab -l | grep -v "check_bbb_salt.sh" > cron.jobs
                    echo "*/5 * * * * $CMD" >> cron.jobs
                    crontab cron.jobs
                    rm cron.jobs
                else
                    /var/mconf/tools/nagios/server_up.sh $NAGIOS_ADDRESS $INSTANCE_TYPE
                fi
            fi
        EOH
end

