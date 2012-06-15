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

bash "create tools folder" do
  cwd "#{Chef::Config[:file_cache_path]}"
  code <<-EOH
    mkdir -p ~/tools
  EOH
end
