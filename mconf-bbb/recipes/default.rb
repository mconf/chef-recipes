# Cookbook Name:: mconf-bbb
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

# Add the BigBlueButton key and repository URL and ensure the multiverse is enabled
script "set_repositories" do
        interpreter "bash"
        user "root"
        cwd "/home/mconf"
        code <<-EOH
        wget http://ubuntu.bigbluebutton.org/bigbluebutton.asc -O- | apt-key add -
        echo "deb http://ubuntu.bigbluebutton.org/lucid_dev_08/ bigbluebutton-lucid main" | tee /etc/apt/sources.list.d/bigbluebutton.list
        echo "deb http://us.archive.ubuntu.com/ubuntu/ lucid multiverse" | tee -a /etc/apt/sources.list
        EOH
end

#install bbb packages
package "bigbluebutton"
package "bbb-demo"
