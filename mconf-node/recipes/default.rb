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
    Chef::Log.info("Updating the Ubuntu package repository")
    sudo apt-get update > /dev/null

    Chef::Log.info("Making tools instalation")
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
  EOH
end
