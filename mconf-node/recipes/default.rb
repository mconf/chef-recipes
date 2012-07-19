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

include_recipe "mconf-bbb"
include_recipe "mconf-monitor"

