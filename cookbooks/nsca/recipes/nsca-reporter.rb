#
# Cookbook Name:: mconf-utils
# Recipe:: nsca-reporter
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

Chef::Log.info("Chef Handlers will be at: #{node[:chef_handler][:handler_path]}")

remote_directory node[:chef_handler][:handler_path] do
  source 'handlers'
  owner 'root'
  group 'root'
  mode "0755"
  recursive true
  action :create
end

chef_handler "NscaHandler" do
  source "#{node[:chef_handler][:handler_path]}/nsca_handler.rb"
  supports :report => true, :exception => true
  arguments [
    :send_nsca_binary => "#{node[:nsca][:dir]}/send_nsca",
    :send_nsca_config => "#{node[:nsca][:config_dir]}/send_nsca.cfg",
    :nsca_server => node[:nsca_handler][:nsca_server],
    :service_name => node[:nsca_handler][:service_name],
    :nsca_timeout => node[:nsca][:timeout],
    :hostname => node[:nsca][:hostname]
  ]
  action :enable
end
