# Cookbook Name:: mconf-node
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#


#force apt get update (chef bug workaround on ant package install)
execute "apt-get update" do
  user "root"
  action :run
end

#install requirements
package "ant"
package "git-core"
package "htop"
package "iftop"
package "curl"

include_recipe "mconf-bbb"
include_recipe "mconf-monitor"

