#
# Cookbook Name:: nsca
# Recipe:: default
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

%w{ zlib1g-dev libmcrypt-dev }.each do |pkg|
  package pkg do
    action :install
  end
end

if node[:nsca][:force_reinstall]
  file "#{node[:nsca][:dir]}/nsca" do
    action :delete
  end
  node.set[:nsca][:force_reinstall] = false
end

cookbook_file "/usr/local/src/nsca.c.v2.9.1.patched" do
  source "nsca.c.v2.9.1.patched"
  mode "0644"
end

# get nsca file from server and call build script if there is a new file
remote_file "/usr/local/src/nsca-#{node[:nsca][:version]}.tar.gz" do
    source "#{node[:nsca][:url]}/nsca-#{node[:nsca][:version]}.tar.gz"
    checksum node[:nsca][:checksum]
    mode "0644"
    action :create_if_missing
end

# build nsca and call installer
script "build nsca" do
    interpreter "bash"
    user "root"
    cwd "/usr/local/src"
    code <<-EOH
        tar xzf "nsca-#{node[:nsca][:version]}.tar.gz"
        cd "nsca-#{node[:nsca][:version]}"

        # \TODO instead of using the complete file patched, use only the patch
        if [ "#{node[:nsca][:version]}" == "2.9.1" ]; then
          mv /usr/local/src/nsca.c.v2.9.1.patched src/nsca.c
        fi
        ./configure
        make all
        make install

        mkdir -p #{node[:nsca][:dir]} #{node[:nsca][:config_dir]}
        cp src/nsca src/send_nsca #{node[:nsca][:dir]}
        cp sample-config/send_nsca.cfg sample-config/nsca.cfg #{node[:nsca][:config_dir]}/
        chmod +r #{node[:nsca][:config_dir]}/*.cfg
    EOH
    action :run
    creates "#{node[:nsca][:dir]}/nsca"
end
