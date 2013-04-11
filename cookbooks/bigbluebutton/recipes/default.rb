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

# dependencies of libvpx and ffmpeg
# http://code.google.com/p/bigbluebutton/wiki/081InstallationUbuntu#3.__Install_ffmpeg
%w( build-essential git-core checkinstall yasm texi2html libopencore-amrnb-dev 
    libopencore-amrwb-dev libsdl1.2-dev libtheora-dev libvorbis-dev libx11-dev 
    libxfixes-dev libxvidcore-dev zlib1g-dev ).each do |pkg|
  package pkg do
    action :install
  end
end

# include_recipe "yasm::source"
include_recipe "ffmpeg"

# https://groups.google.com/d/topic/bigbluebutton-setup/zL5Lwbj46TY/discussion
package "language-pack-en" do
  action :install
  notifies :run, "execute[update locale]", :immediately
end

execute "update locale" do
  user "root"
  command "update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8"
  action :nothing
end

# add ubuntu repo
apt_repository "ubuntu" do
  uri "http://archive.ubuntu.com/ubuntu/"
  components ["lucid" , "multiverse"]
end

# add bigbluebutton repo
apt_repository "bigbluebutton" do
  key "http://ubuntu.bigbluebutton.org/bigbluebutton.asc"
  uri "http://ubuntu.bigbluebutton.org/lucid_dev_08"
  components ["bigbluebutton-lucid" , "main"]
  notifies :run, 'execute[apt-get update]', :immediately
end

package "bigbluebutton" do
  # we won't use the version for bigbluebutton and bbb-demo because the 
  # BigBlueButton folks don't keep the older versions
#  version node[:bbb][:version]
  response_file "bigbluebutton.seed"
  action :install
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

link "/etc/nginx/sites-enabled/bigbluebutton" do
  to "/etc/nginx/sites-available/bigbluebutton"
end

include_recipe "bigbluebutton::load-properties"

logrotate_app "tomcat" do
  cookbook "logrotate"
  path "/var/log/tomcat6/catalina.out"
  options [ "missingok", "compress", "copytruncate", "notifempty" ]
  frequency "daily"
  rotate 15
  size "15M"
end

cron "remove old bigbluebutton logs" do
  hour "1"
  minute "0"
  command "find /var/log/bigbluebutton -name '*.log*' -mtime +15 -exec rm -r '{}' \\"
  action :create
end

template "/etc/cron.daily/bigbluebutton" do
  source "bigbluebutton.erb"
  variables(
    :keep_files_newer_than => node[:bbb][:keep_files_newer_than]
  )
end

package "bbb-demo" do
#  version node[:bbb_demo][:version]
  if node[:bbb][:demo][:enabled]
    action :install
  else
    action :purge
  end
end

template "deploy red5 deskshare conf" do
  path "/usr/share/red5/webapps/deskshare/WEB-INF/red5-web.xml"
  source "red5-web-deskshare.xml.erb"
  mode "0644"
  variables(
    :record_deskshare => node[:bbb][:recording][:deskshare]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

template "deploy red5 video conf" do
  path "/usr/share/red5/webapps/video/WEB-INF/red5-web.xml"
  source "red5-web-video.xml.erb"
  mode "0644"
  variables(
    :record_video => node[:bbb][:recording][:video]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

directory "video streams dir" do
  path "/usr/share/red5/webapps/video/streams"
  user "red5"
  group "adm"
  mode "0755"
  action :create
end

template "/opt/freeswitch/conf/vars.xml" do
  source "vars.xml.erb"
  group "daemon"
  owner "freeswitch"
  mode "0755"
  variables(
    :external_ip => node[:bbb][:external_ip] == node[:bbb][:internal_ip]? "auto-nat": node[:bbb][:external_ip]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

{ "external.xml" => "/opt/freeswitch/conf/sip_profiles/external.xml",
  "conference.conf.xml" => "/opt/freeswitch/conf/autoload_configs/conference.conf.xml" }.each do |k,v|
  cookbook_file v do
    source k
    group "daemon"
    owner "freeswitch"
    mode "0755"
    notifies :run, "execute[restart bigbluebutton]", :delayed
  end
end

ruby_block "reset enforce salt flag" do
    block do
        node.set[:bbb][:enforce_salt] = nil
        node.set[:bbb][:setsalt_needed] = false
    end
    only_if do node[:bbb][:setsalt_needed] end
    notifies :run, "execute[set bigbluebutton salt]", :immediately
end

execute "set bigbluebutton salt" do
    user "root"
    command "bbb-conf --setsalt #{node[:bbb][:salt]}"
    action :nothing
    notifies :run, "execute[restart bigbluebutton]", :delayed
end

execute "set bigbluebutton ip" do
    user "root"
    command "bbb-conf --setip #{node[:bbb][:server_addr]}; exit 0"
    action :run
    only_if do node[:bbb][:setip_needed] end
end

ruby_block "reset restart flag" do
    block do
        node.set[:bbb][:force_restart] = false
    end
    only_if do node[:bbb][:force_restart] end
    notifies :run, "execute[restart bigbluebutton]", :delayed
end

service "bbb-record-core" do
  action :start
end

execute "restart bigbluebutton" do
  user "root"
  command "bbb-conf --clean || echo 'Return successfully'"
  action :nothing
end
