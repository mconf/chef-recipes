#
# Cookbook Name:: mconf-node
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#


#file "/tmp/working_with_git" do
#  content "I'm working with git."
#end


template "/tmp/mconf/mconf_config_file" do
    owner "mconf"
    group "mconf"
    mode 00640
    source "mconf_config_file"

package "git-core"
package "htop"
package "iftop"
package "ant"
package "curl"


