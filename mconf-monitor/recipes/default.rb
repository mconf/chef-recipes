# Cookbook Name:: mconf-monitor
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

#package "zlib1g-dev"
#package "git-core"
#package "python-dev"
#package "python-argparse"
#package "subversion"

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


