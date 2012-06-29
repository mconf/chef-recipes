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


node.default["mconf"]["nagios_address"] = "localhost"
node.default["mconf"]["instance_type"] = "nagios"
node.default["mconf"]["interval"] = "360"

#get nagios repo
script "nagios_repo" do
        interpreter "bash"
        user "mconf"
        cwd "/home/mconf/"
        code <<-EOH
        mkdir -p /tools
        cd /tools/
        if [ -d "nagios-etc" ]
        then
        cd nagios-etc/
            /tools/nagios-etc/cli/performance_report.py stop
            git pull origin master
            cd ..
        else
        git clone git://github.com/mconf/nagios-etc.git
        fi
        EOH
end

#get psutil and build it
script "install_psutil" do
        interpreter "bash"
        user "mconf"
        cwd "/home/mconf/"
        code <<-EOH
        mkdir -p /downloads

        cd /downloads/
        if [ -d "psutil-read-only" ]
        then
        cd psutil-read-only/
            svn update
            cd ..
        else
            # we are using the svn trunk instead of the lastest stable tag because of this:
            # http://code.google.com/p/psutil/issues/detail?id=248
            svn checkout http://psutil.googlecode.com/svn/trunk psutil-read-only
        fi
        cd psutil-read-only/
        python setup.py build
        EOH
end

#then install psutil as root
script "install_psutil" do
        interpreter "bash"
        user "root"
        cwd "/home/mconf/downloads/psutil-read-only/"
        code <<-EOH
        python setup.py install
        EOH
end

#set up nsca sender
script "install_psutil" do
        interpreter "bash"
        user "root"
        cwd "/home/mconf/downloads/"
        code <<-EOH 
        NSCA_VERSION="2.7.2"
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

        cd ~/downloads/$NSCA/
        if [ INSTANCE_TYPE == "nagios" ]
        then
            cp src/nsca /usr/local/nagios/bin/
            cp sample-config/nsca.cfg /usr/local/nagios/etc/
            chmod a+r /usr/local/nagios/etc/nsca.cfg
            # install as XINETD service
            cp ~/downloads/$NSCA/sample-config/nsca.xinetd /etc/xinetd.d/nsca
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
