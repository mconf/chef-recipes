#
# Cookbook Name:: nsca
# Recipe:: client
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

include_recipe "nsca::default"

# nsca install procedure 
script "install nsca sender" do
    interpreter "bash"
    user "root"
    cwd "#{Chef::Config[:file_cache_path]}/nsca-#{node[:nsca][:version]}"
    code <<-EOH
        mkdir -p #{node[:nsca][:dir]} #{node[:nsca][:config_dir]}
        cp src/send_nsca #{node[:nsca][:dir]}
        cp sample-config/send_nsca.cfg #{node[:nsca][:config_dir]}/
        chmod +r #{node[:nsca][:config_dir]}/send_nsca.cfg
    EOH
    action :run
    creates "#{node[:nsca][:dir]}/send_nsca"
    creates "#{node[:nsca][:config_dir]}/send_nsca.cfg"
end
