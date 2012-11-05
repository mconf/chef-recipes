# Cookbook Name:: mconf-node
# Recipe:: base
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute

user "#{node[:mconf][:user]}" do
  action :create  
end

[ "#{node[:mconf][:dir]}",
  "#{node[:mconf][:log][:dir]}",
  "#{node[:mconf][:tools][:dir]}" ].each do |t|
    directory t do
        owner "#{node[:mconf][:user]}"
        group "#{node[:mconf][:user]}"
        recursive true
        action :create
    end
end

# create the cache directory if it doesn't exist
directory "#{Chef::Config[:file_cache_path]}" do
  recursive true
  action :create
end
