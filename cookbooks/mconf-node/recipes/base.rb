#
# Cookbook Name:: mconf-node
# Recipe:: base
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

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
