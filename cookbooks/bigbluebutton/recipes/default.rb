#
# Cookbook Name:: bigbluebutton
# Recipe:: default
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

include_recipe "ruby-1.9.2"
include_recipe "apt"

link "/usr/bin/ruby1.9.2" do
  to "/usr/local/bin/ruby"
end

%w( god ).each do |g|
  gem_package g do
    action :install
    gem_binary('/usr/local/bin/gem')
  end
end

# add ubuntu repo
apt_repository "ubuntu" do
  uri "http://archive.ubuntu.com/ubuntu/"
  components ["lucid" , "multiverse"]
end

# create the cache directory
directory "#{Chef::Config[:file_cache_path]}" do
  recursive true
  action :create
end

# add bigbluebutton repo
apt_repository "bigbluebutton" do
  key "http://ubuntu.bigbluebutton.org/bigbluebutton.asc"
  uri "http://ubuntu.bigbluebutton.org/lucid_dev_08"
  components ["bigbluebutton-lucid" , "main"]
  # it definitely doesn't work
#  notifies :run, 'execute[apt-get update]', :immediately
end

execute "apt-get update" do
  user "root"
  action :run
end

package "bigbluebutton" do
  # we won't use the version for bigbluebutton and bbb-demo because the 
  # BigBlueButton folks don't keep the older versions
#  version node[:bbb][:version]
  response_file "bigbluebutton.seed"
  action :install
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

include_recipe "bigbluebutton::load-properties"

package "bbb-demo" do
#  version node[:bbb_demo][:version]
  if node[:bbb][:demo][:enabled]
    action :install
  else
    action :purge
  end
end

template "/usr/share/red5/webapps/deskshare/WEB-INF/red5-web.xml" do
  source "red5-web-deskshare.xml"
  mode "0644"
  variables(
    :record_deskshare => node[:bbb][:recording][:deskshare]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

template "/usr/share/red5/webapps/video/WEB-INF/red5-web.xml" do
  source "red5-web-video.xml"
  mode "0644"
  variables(
    :record_video => node[:bbb][:recording][:video]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

execute "set bigbluebutton ip" do
    user "root"
    command "bbb-conf --setip #{node[:bbb][:server_addr]}; exit 0"
    action :run
    only_if do node[:bbb][:setsalt_needed] end
end

execute "restart bigbluebutton" do
  user "root"
  command "bbb-conf --clean"
  action :nothing
end

