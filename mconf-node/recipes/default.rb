# Cookbook Name:: mconf-node
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#


#install requirements
package "git-core"
package "htop"
package "iftop"
package "ant"
package "curl"

#ip used to set bbb
node.default["mconf"]["bbbip"] = node[:ipaddress]

#create instalation script folder
script "install_tools" do
        interpreter "bash"
        user "mconf"
        cwd "/home/mconf"
        code <<-EOH
#temp sysop test
        if [ `lsb_release --description | grep 'Ubuntu 10.04' | wc -l` -eq 0 ]
        then
        echo "A Mconf node MUST BE a fresh installation of Ubuntu 10.04 Server"
            exit 1
        fi
#temp end
        mkdir -p tools
        cd tools
        if [ -d "installation-scripts" ]
        then
                cd installation-scripts
                git pull origin master
                cd ..
        else
                git clone git://github.com/mconf/installation-scripts.git
        fi
        EOH
end

#install bbb and sets ip
script "install_bbb" do
        interpreter "bash"
        ENV['BBBIP'] = node.default["mconf"]["bbbip"]
        user "mconf"
        cwd "/home/mconf/tools/installation-scripts/bbb-deploy/"
        code <<-EOH
        chmod +x install-bigbluebutton.sh
        ./install-bigbluebutton.sh
        sudo bbb-conf --setip $BBBIP
        EOH
end

#install notes
script "install_notes" do
        interpreter "bash"
        user "mconf"
        cwd "/home/mconf/tools/installation-scripts/bbb-deploy/"
        code <<-EOH
        chmod +x install-notes.sh
        ./install-notes.sh
        EOH
end

#install monitor
script "install_monitor" do
        interpreter "bash"
        user "mconf"
        cwd "/home/mconf/tools/installation-scripts/bbb-deploy/"
        code <<-EOH
        chmod +x install-monitor.sh
        #./install-monitor.sh lb.mconf.org bigbluebutton 10
        EOH
end

#get custom bbb
script "apply_custom_bbb" do
        interpreter "bash"
        user "mconf"
        cwd "/home/mconf/tools/installation-scripts/bbb-deploy/"
        code <<-EOH
        VERSION=$(curl http://mconf.org:8888/mconf-node/current.txt)
        wget -O bigbluebutton.zip "http://mconf.org:8888/mconf-node/$VERSION"
        sudo ant -f deploy_target.xml deploy
        EOH
end

#install presentation
script "install_presentation" do
        interpreter "bash"
        user "mconf"
        cwd "/home/mconf/tools/installation-scripts/bbb-deploy/"
        code <<-EOH
        chmod +x mconf-presentation.sh
        ./mconf-presentation.sh
        EOH
end

#install mobile fs
script "install_mobiles_fs" do
        interpreter "bash"
        user "mconf"
        cwd "/home/mconf/tools/installation-scripts/bbb-deploy/"
        code <<-EOH
        chmod +x enable-mobile-fs.sh
        ./enable-mobile-fs.sh
        EOH
end

