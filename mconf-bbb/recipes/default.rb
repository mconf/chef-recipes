# Cookbook Name:: mconf-bbb
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

include_recipe "ruby-1.9.2"

#add ubuntu repo
apt_repository "ubuntu-us" do
  uri "http://us.archive.ubuntu.com/ubuntu"
  components ["lucid" , "multiverse"]
end

#add bbb repo
apt_repository "bigbluebutton" do
  key "http://ubuntu.bigbluebutton.org/bigbluebutton.asc"
  uri "http://ubuntu.bigbluebutton.org/lucid_dev_08"
  components ["bigbluebutton-lucid" , "main"]
end

#install bbb packages
package "bigbluebutton"
package "bbb-demo"
