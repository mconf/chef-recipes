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

#create performance reporter script
template "/var/mconf/tools/nagios/performance_report.py" do
  source "performance_report.py"
  mode 0755
  owner "mconf"
  action :create_if_missing
end

#set up nsca sender
script "set_up_nsca_sender" do
        interpreter "bash"
        user "root"
        cwd "/var/mconf/tools/nagios/"
        not_if do File.exists?('/usr/local/nagios/bin/send_nsca') end
        code <<-EOH
            NSCA_VERSION=#{node[:mconf][:ncsa_version]}
            NSCA="nsca-$NSCA_VERSION"
            NSCA_TAR="$NSCA.tar.gz"
            if [ ! -f "NSCA_TAR" ]
            then
                wget -nc http://prdownloads.sourceforge.net/sourceforge/nagios/$NSCA_TAR
                tar xzf $NSCA_TAR
                cd $NSCA
                ./configure
                make
                make install
            fi

            cd /var/mconf/tools/nagios/$NSCA/
            
            if [ INSTANCE_TYPE == "nagios" ]
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

#make monitor install
script "install_monitor" do
        interpreter "bash"
        user "mconf"
        environment({
          'INSTANCE_TYPE' => node.default["mconf"]["instance_type"],
          'NAGIOS_ADDRESS' => node.default["mconf"]["nagios_address"],
          'INTERVAL' => node.default["mconf"]["interval"]
        })
        cwd "/home/mconf/"
        code <<-EOH
            function get_hostname
            {
                if [ `which bbb-conf | wc -l` -eq 0 ]
                then
                echo $(ifconfig | grep -v '127.0.0.1' | grep -E "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | head -1 | cut -d: -f2 | awk '{ print NAGIOS_ADDRESS}')
                else
                echo `bbb-conf --salt | grep 'URL' | tr -d ' ' | sed 's:URL\:http\://\([^:/]*\).*:\1:g'`
                fi
            }

            if [ INSTANCE_TYPE == "nagios" ]
            then
            HOST="localhost"
            else
            HOST=`get_hostname`
            fi

            if [ INSTANCE_TYPE != "nagios" ]
            then
                echo "Sending the Nagios packet to start monitoring"
                if [ INSTANCE_TYPE == "bigbluebutton" ]
                then
                CMD="~/tools/nagios-etc/cli/check_bbb_salt.sh $NAGIOS_ADDRESS $INTERVAL | tee /tmp/output_check_bbb_salt.txt 2>&1"
                eval $CMD
                # add a cron job to check if there's any modification on the BigBlueButton URL or salt
                crontab -l | grep -v "check_bbb_salt.sh" > cron.jobs
                echo "*/5 * * * * $CMD" >> cron.jobs
                crontab cron.jobs
                rm cron.jobs
                else
                    ~/tools/nagios-etc/cli/server_up.sh $NAGIOS_ADDRESS $INSTANCE_TYPE
                fi
            fi

            chmod +x ~/tools/installation-scripts/bbb-deploy/start-monitor.sh
            ~/tools/installation-scripts/bbb-deploy/start-monitor.sh $NAGIOS_ADDRESS $HOST $INTERVAL
        EOH
end
