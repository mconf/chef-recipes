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
    Chef::Log.info("Creating tools directory")
    mkdir -p ~/tools
    cd ~/tools
  EOH
end
