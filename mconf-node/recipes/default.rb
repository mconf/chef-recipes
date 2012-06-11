#
# Cookbook Name:: mconf-node
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#


package "git-core"
package "htop"
package "iftop"
package "ant"
package "curl"


bash "install mypackage" do
  cwd "#{Chef::Config[:file_cache_path]}"
  code <<-EOH
    #!/bin/bash

    function print_usage
    {
	    echo "Usage:"
	    echo "    $0 <domain_name>"
	    exit 1
    }

    if [ `lsb_release --description | grep 'Ubuntu 10.04' | wc -l` -eq 0 ]
    then
        echo "A Mconf node MUST BE a fresh installation of Ubuntu 10.04 Server"
        exit 1
    fi

    if [ `whoami` == "root" ]
    then
        echo "This script shouldn't be executed as root"
        exit 1
    fi

    echo "Updating the Ubuntu package repository"
    sudo apt-get update > /dev/null

    mkdir -p ~/tools
    cd ~/tools
    if [ -d "installation-scripts" ]
    then
        cd installation-scripts
        git pull origin master
        cd ..
    else
        git clone git://github.com/mconf/installation-scripts.git
    fi
    cd installation-scripts/bbb-deploy/

    chmod +x install-bigbluebutton.sh
    ./install-bigbluebutton.sh
    sudo bbb-conf --setip #{node[:mconf][:lbip]}

    chmod +x install-notes.sh
    ./install-notes.sh

    chmod +x install-monitor.sh
    ./install-monitor.sh lb.mconf.org bigbluebutton 10

    VERSION=$(curl http://mconf.org:8888/mconf-node/current.txt)
    wget -O bigbluebutton.zip "http://mconf.org:8888/mconf-node/$VERSION"
    sudo ant -f deploy_target.xml deploy

    chmod +x mconf-presentation.sh
    ./mconf-presentation.sh

    chmod +x enable-mobile-fs.sh
    ./enable-mobile-fs.sh

    echo "Restart the server to finish the installation"
    echo "It will take a while to start the live notes server, please be patient"
  EOH
end

template "/etc/mconf/mconf.conf" do
  source "mconf_config_file"
  mode "0644"
  variables(
      :loadbalanceip => node[:mconf][:lbip],
    )
end
