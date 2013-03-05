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

require 'digest/sha1'
require 'net/http'

include_recipe "ruby-1.9.2"
include_recipe "apt"

link "/usr/bin/ruby1.9.2" do
  to "/usr/local/bin/ruby"
end

# https://groups.google.com/d/topic/bigbluebutton-setup/zL5Lwbj46TY/discussion
package "language-pack-en" do
  action :install
  notifies :run, "execute[update locale]", :immediately
end

execute "update locale" do
  user "root"
  command "update-locale LANG=en_US.UTF-8"
  action :nothing
end

%w( god builder bundler ).each do |g|
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

# dependencies of libvpx and ffmpeg
# http://code.google.com/p/bigbluebutton/wiki/081InstallationUbuntu#3.__Install_ffmpeg
%w( build-essential git-core checkinstall yasm texi2html libopencore-amrnb-dev 
    libopencore-amrwb-dev libsdl1.2-dev libtheora-dev libvorbis-dev libx11-dev 
    libxfixes-dev libxvidcore-dev zlib1g-dev ).each do |pkg|
  package "#{pkg}" do
    action :install
  end
end

script "install libvpx" do
  interpreter "bash"
  user "root"
  cwd "/usr/local/src"
  code <<-EOH
    git clone http://git.chromium.org/webm/libvpx.git
    cd libvpx
    ./configure
    make
    make install
  EOH
  only_if do not File.exists?("/usr/local/src/libvpx") end
end

script "install ffmpeg" do
  interpreter "bash"
  user "root"
  cwd "/usr/local/src"
  code <<-EOH
    wget http://ffmpeg.org/releases/ffmpeg-0.11.2.tar.gz
    tar -xvzf ffmpeg-0.11.2.tar.gz
    cd ffmpeg-0.11.2
    ./configure  --enable-version3 --enable-postproc  --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libtheora --enable-libvorbis  --enable-libvpx
    make
    checkinstall --pkgname=ffmpeg --pkgversion="5:$(./version.sh)" --backup=no --deldoc=yes --default
  EOH
  only_if do not File.exists?("/usr/local/src/ffmpeg-0.11.2") end
end

package "bigbluebutton" do
  # we won't use the version for bigbluebutton and bbb-demo because the 
  # BigBlueButton folks don't keep the older versions
#  version node[:bbb][:version]
  response_file "bigbluebutton.seed"
  action :install
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

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

include_recipe "bigbluebutton::load-properties"

ruby_block "check meetings running" do
  block do
    params = "random=#{rand(99999)}"
    checksum = Digest::SHA1.hexdigest "getMeetings#{params}#{node[:bbb][:salt]}"
    url = URI.parse("http://localhost:8080/bigbluebutton/api/getMeetings?#{params}&checksum=#{checksum}")
    req = Net::HTTP::Get.new(url.to_s)
    res = Net::HTTP.start(url.host, url.port) { |http|
      http.request(req)
    }

    if not res.body.include? "<messageKey>noMeetings</messageKey>"
      raise "Can't continue because there are meetings currently running"
    end
  end
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
  source "red5-web-deskshare.xml"
  mode "0644"
  variables(
    :record_deskshare => node[:bbb][:recording][:deskshare]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

template "deploy red5 video conf" do
  path "/usr/share/red5/webapps/video/WEB-INF/red5-web.xml"
  source "red5-web-video.xml"
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

{ "vars.xml" => "/opt/freeswitch/conf/vars.xml",
  "external.xml" => "/opt/freeswitch/conf/sip_profiles/external.xml",
  "conference.conf.xml" => "/opt/freeswitch/conf/autoload_configs/conference.conf.xml" }.each do |k,v|
  cookbook_file "#{v}" do
    source "#{k}"
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

execute "restart bigbluebutton" do
  user "root"
  command "bbb-conf --clean || echo 'Return successfully'"
  action :nothing
end
