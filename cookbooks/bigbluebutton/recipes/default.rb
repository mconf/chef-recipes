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

ruby_block "check system architecture" do
  block do
    raise "This recipe requires a 64 bits machine"
  end
  only_if { node[:kernel][:machine] != "x86_64" }
end

if node[:bbb][:ffmpeg][:install_method] == "package"
  current_ffmpeg_version = `ffmpeg -version | grep 'ffmpeg version' | cut -d' ' -f3`.strip!
  ffmpeg_update_needed = (current_ffmpeg_version != node[:bbb][:ffmpeg][:version])

  remote_file "#{Chef::Config[:file_cache_path]}/#{node[:bbb][:ffmpeg][:filename]}" do
    source "#{node[:bbb][:ffmpeg][:repo_url]}/#{node[:bbb][:ffmpeg][:filename]}"
    action :create
    only_if { ffmpeg_update_needed }
  end

  dpkg_package "ffmpeg" do
    source "#{Chef::Config[:file_cache_path]}/#{node[:bbb][:ffmpeg][:filename]}"
    action :install
    only_if { ffmpeg_update_needed }
  end
else
  # dependencies of libvpx and ffmpeg
  # http://code.google.com/p/bigbluebutton/wiki/081InstallationUbuntu#3.__Install_ffmpeg
  %w( build-essential git-core checkinstall yasm texi2html libopencore-amrnb-dev 
      libopencore-amrwb-dev libsdl1.2-dev libtheora-dev libvorbis-dev libx11-dev 
      libxfixes-dev libxvidcore-dev zlib1g-dev ).each do |pkg|
    package pkg do
      action :install
    end
  end

  # ffmpeg already includes libvpx
  include_recipe "ffmpeg"
end

if node[:bbb][:libvpx][:install_method] == "package"
  remote_file "#{Chef::Config[:file_cache_path]}/#{node[:bbb][:libvpx][:filename]}" do
    source "#{node[:bbb][:libvpx][:repo_url]}/#{node[:bbb][:libvpx][:filename]}"
    action :create_if_missing
  end

  dpkg_package "libvpx" do
    source "#{Chef::Config[:file_cache_path]}/#{node[:bbb][:libvpx][:filename]}"
    action :install
  end
else
  if node[:bbb][:ffmpeg][:install_method] == "source"
    # do nothing because ffmpeg already installed libvpx
  else
    include_recipe "libvpx::source"
  end
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node[:bbb][:openoffice][:filename]}" do
  source "#{node[:bbb][:openoffice][:repo_url]}/#{node[:bbb][:openoffice][:filename]}"
  action :create_if_missing
end

dpkg_package "openoffice" do
  source "#{Chef::Config[:file_cache_path]}/#{node[:bbb][:openoffice][:filename]}"
  action :install
end

package "python-software-properties"

apt_repository "libreoffice" do
  uri "http://ppa.launchpad.net/libreoffice/libreoffice-4-0/ubuntu"
  components ["lucid", "main"]
  keyserver "keyserver.ubuntu.com"
  key "1378B444"
end

package "libreoffice-common"
package "libreoffice"

# add ubuntu repo
apt_repository "ubuntu" do
  uri "http://archive.ubuntu.com/ubuntu/"
  components ["lucid" , "multiverse"]
end

# add bigbluebutton repo
apt_repository node[:bbb][:bigbluebutton][:package_name] do
  key node[:bbb][:bigbluebutton][:key_url]
  uri node[:bbb][:bigbluebutton][:repo_url]
  components node[:bbb][:bigbluebutton][:components]
  notifies :run, 'execute[apt-get update]', :immediately
end

package "red5" do
  options "-o Dpkg::Options::=\"--force-confnew\""
  action :upgrade
end

execute "upgrade bigbluebutton dependencies" do
  command "apt-get -y -o Dpkg::Options::=\"--force-confnew\" dist-upgrade"
  action :nothing
end

# install bigbluebutton package
package node[:bbb][:bigbluebutton][:package_name] do
  response_file "bigbluebutton.seed"
  # it will force the maintainer's version of the configuration files
  options "-o Dpkg::Options::=\"--force-confnew\""
  action :upgrade
  notifies :run, "execute[upgrade bigbluebutton dependencies]", :immediately
  notifies :run, "execute[clean bigbluebutton]", :delayed
end

package "bbb-playback-presentation" do
  options "-o Dpkg::Options::=\"--force-confnew\""
  action :upgrade
end

execute "check freeswitch old version" do
  command "apt-get -y purge bbb-freeswitch && apt-get -y -o Dpkg::Options::=\"--force-confnew\" install #{node[:bbb][:bigbluebutton][:package_name]}"
  action :run
  notifies :run, "execute[clean bigbluebutton]", :delayed
  only_if do `bbb-conf --check | grep 'You have an older version of FreeSWITCH installed.' | wc -l`.strip! != "0" end
end

# if anything goes wrong with the command above, it won't fail,
# so I will make it fail here
execute "force apt fix" do
  command "apt-get -f -y -o Dpkg::Options::=\"--force-confnew\" install"
  action :run
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
  if node[:bbb][:demo][:enabled]
    action :upgrade
  else
    action :purge
  end
end

file "/var/lib/tomcat6/webapps/demo.war" do
  action :touch
  only_if do node[:bbb][:demo][:enabled] and `bbb-conf --check | grep 'Error: The updated demo.war did not deploy.' | wc -l`.strip! != "0" end
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

template "/opt/freeswitch/conf/autoload_configs/conference.conf.xml" do
  source "conference.conf.xml.erb"
  group "daemon"
  owner "freeswitch"
  mode "0755"
  variables(
    :enable_comfort_noise => node[:bbb][:enable_comfort_noise],
    :enable_freeswitch_sounds => node[:bbb][:enable_freeswitch_sounds],
    :enable_freeswitch_hold_music => node[:bbb][:enable_freeswitch_hold_music]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

{ "external.xml" => "/opt/freeswitch/conf/sip_profiles/external.xml" }.each do |k,v|
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
  provider Chef::Provider::Service::Init::Debian
  pattern "god"
  supports :start => true, :stop => true, :restart => true
  action :start
end

execute "service bbb-record-core restart" do
  action :run
  only_if do `bbb-conf --check | grep 'Not Running:  bbb-record-core' | wc -l`.strip! != "0" end
end

template "/usr/local/bigbluebutton/core/scripts/presentation.yml" do
  source "presentation.yml.erb"
  mode "0644"
  variables(
    :video_output_width => node[:bbb][:recording][:presentation][:video_output_width],
    :video_output_height => node[:bbb][:recording][:presentation][:video_output_height],
    :audio_offset => node[:bbb][:recording][:presentation][:audio_offset],
    :include_deskshare => node[:bbb][:recording][:presentation][:include_deskshare]
  )
end

execute "check voice application register" do
  command "echo 'Restarting because the voice application failed to register with the sip server'"
  only_if do `bbb-conf --check | grep 'Error: The voice application failed to register with the sip server.' | wc -l`.strip! != "0" end
  notifies :run, "execute[clean bigbluebutton]", :delayed
end

execute "clean bigbluebutton" do
  user "root"
  command "bbb-conf --clean || echo 'Return successfully'"
  action :nothing
end

execute "restart bigbluebutton" do
  user "root"
  command "bbb-conf --restart || echo 'Return successfully'"
  action :nothing
end

node[:bbb][:recording][:rebuild].each do |record_id|
  execute "rebuild recording" do
    user "root"
    command "bbb-record --rebuild #{record_id}"
    action :run
  end
end
node.set[:bbb][:recording][:rebuild] = []

ruby_block "collect packages version" do
  block do
    packages = [ "bbb-*", "red5", node[:bbb][:bigbluebutton][:package_name], "ffmpeg", "libvpx" ]
    packages_version = {}
    packages.each do |pkg|
      output = `dpkg -l | grep "#{pkg}"`
      output.split("\n").each do |entry|
        entry = entry.split()
        packages_version[entry[1]] = entry[2]
      end
    end
    node.set[:bbb][:bigbluebutton][:packages_version] = packages_version
  end
end
