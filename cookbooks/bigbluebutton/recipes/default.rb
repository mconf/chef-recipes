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

execute "fix dpkg" do
  command "dpkg --configure -a"
  action :run
end

execute "apt-get update"

node[:bbb][:ffmpeg][:dependencies].each do |pkg|
  package pkg
end

if node[:bbb][:ffmpeg][:install_method] == "package"
  current_ffmpeg_version = `ffmpeg -version | grep 'ffmpeg version' | cut -d' ' -f3`.strip!
  ffmpeg_update_needed = (current_ffmpeg_version != node[:bbb][:ffmpeg][:version])
  ffmpeg_dst = "/tmp/#{node[:bbb][:ffmpeg][:filename]}"

  remote_file ffmpeg_dst do
    source "#{node[:bbb][:ffmpeg][:repo_url]}/#{node[:bbb][:ffmpeg][:filename]}"
    action :create
    only_if { ffmpeg_update_needed }
  end

  dpkg_package "ffmpeg" do
    source ffmpeg_dst
    action :install
    only_if { ffmpeg_update_needed }
  end
else
  # dependencies of libvpx and ffmpeg
  # https://code.google.com/p/bigbluebutton/wiki/090InstallationUbuntu#3.__Install_ffmpeg
  %w( build-essential git-core checkinstall yasm texi2html libvorbis-dev 
      libx11-dev libxfixes-dev zlib1g-dev pkg-config netcat ).each do |pkg|
    package pkg do
      action :install
    end
  end

  ffmpeg_repo = "#{Chef::Config[:file_cache_path]}/ffmpeg"

  execute "set ffmpeg version" do
    command "cp #{ffmpeg_repo}/RELEASE #{ffmpeg_repo}/VERSION"
    action :nothing
    subscribes :run, "git[#{ffmpeg_repo}]", :immediately
  end

  # ffmpeg already includes libvpx
  include_recipe "ffmpeg"
end

if node[:bbb][:libvpx][:install_method] == "package"
  libvpx_dst = "/tmp/#{node[:bbb][:libvpx][:filename]}"

  remote_file libvpx_dst do
    source "#{node[:bbb][:libvpx][:repo_url]}/#{node[:bbb][:libvpx][:filename]}"
    action :create_if_missing
  end

  dpkg_package "libvpx" do
    source libvpx_dst
    action :install
  end
else
  if node[:bbb][:ffmpeg][:install_method] == "source"
    # do nothing because ffmpeg already installed libvpx
  else
    include_recipe "libvpx::source"
  end
end

# add ubuntu repo
apt_repository "ubuntu" do
  uri "http://archive.ubuntu.com/ubuntu/"
  components ["trusty" , "multiverse"]
end

# add bigbluebutton repo
apt_repository node[:bbb][:bigbluebutton][:package_name] do
  key node[:bbb][:bigbluebutton][:key_url]
  uri node[:bbb][:bigbluebutton][:repo_url]
  components node[:bbb][:bigbluebutton][:components]
  notifies :run, 'execute[apt-get update]', :immediately
end

# package response_file isn't working properly, that's why we have to accept the licenses with debconf-set-selections
execute "accept mscorefonts license" do
  user "root"
  command "echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections"
  action :run
end

# install bigbluebutton package
package node[:bbb][:bigbluebutton][:package_name] do
  response_file "bigbluebutton.seed"
  # it will force the maintainer's version of the configuration files
  options "-o Dpkg::Options::='--force-confnew'"
  action :install
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

ruby_block "upgrade dependencies recursively" do
  block do
    to_upgrade = `apt-get --dry-run --show-upgraded dist-upgrade`.split("\n").select { |l| l.start_with? "Inst" }.collect { |l| l.split()[1] }
    restart_required = ! ( to_upgrade.select { |u| u.start_with? "bbb-" or u.start_with? "mconf-" or [ node[:bbb][:bigbluebutton][:package_name], "tomcat7" ].include? u }.empty? )
    system("apt-get -o Dpkg::Options::='--force-confnew' -y dist-upgrade")
    status = $?
    if not status.success?
      raise "Couldn't upgrade the dependencies recursively"
    end
    
    resources(:execute => "restart bigbluebutton").run_action(:run) if restart_required
  end
  action :run
end

include_recipe "bigbluebutton::load-properties"

template "/etc/cron.daily/bigbluebutton" do
  source "bigbluebutton.erb"
  variables(
    :keep_files_newer_than => node[:bbb][:keep_files_newer_than]
  )
end

{ "external.xml" => "/opt/freeswitch/conf/sip_profiles/external.xml" }.each do |k,v|
  cookbook_file v do
    source k
    group "daemon"
    owner "freeswitch"
    mode "0640"
    notifies :run, "execute[restart bigbluebutton]", :delayed
  end
end

template "/opt/freeswitch/conf/vars.xml" do
  source "vars.xml.erb"
  group "daemon"
  owner "freeswitch"
  mode "0640"
  variables(
    :external_ip => node[:bbb][:external_ip] == node[:bbb][:internal_ip]? "auto-nat": node[:bbb][:external_ip]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

package "bbb-demo" do
  if node[:bbb][:demo][:enabled]
    action :upgrade
    notifies :run, "bash[wait for bbb-demo]", :immediately
  else
    action :purge
  end
end

bash "wait for bbb-demo" do
  code <<-EOH
    SECS=10
    while [[ 0 -ne $SECS ]]; do
      if [ -d /var/lib/tomcat7/webapps/demo ] && [ /var/lib/tomcat7/webapps/demo -nt /var/lib/tomcat7/webapps/demo.war ]; then
        echo "bbb-demo deployed!"
        break;
      fi
      sleep 1
      SECS=$[$SECS-1]
    done
  EOH
  action :nothing
end

package "bbb-check" do
  if node[:bbb][:check][:enabled]
    action :upgrade
  else
    action :purge
  end
end

include_recipe "bigbluebutton::open4"

ruby_block "configure recording workflow" do
    block do
        Dir.glob("/usr/local/bigbluebutton/core/scripts/process/*.rb*").each do |filename|
          format = File.basename(filename).split(".")[0]
          if node[:bbb][:recording][:playback_formats].split(",").include? format
            Chef::Log.info("Enabling record and playback format #{format}");
            command_execute("bbb-record --enable #{format}")
          else
            Chef::Log.info("Disabling record and playback format #{format}");
            command_execute("bbb-record --disable #{format}")
          end
        end
    end
end

execute "check voice application register" do
  command "echo 'Restarting because the voice application failed to register with the sip server'"
  only_if do `bbb-conf --check | grep 'Error: The voice application failed to register with the sip server.' | wc -l`.strip! != "0" end
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

execute "restart bigbluebutton" do
  user "root"
  command "echo 'Restarting'"
  action :nothing
  notifies :run, "execute[set bigbluebutton ip]", :delayed
  notifies :run, "execute[enable webrtc]", :delayed
  notifies :run, "execute[clean bigbluebutton]", :delayed
end

execute "set bigbluebutton salt" do
  user "root"
  command "bbb-conf --setsalt #{node[:bbb][:salt]}"
  action :nothing
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

execute "set bigbluebutton ip" do
  user "root"
  command lazy { "bbb-conf --setip #{node[:bbb][:server_domain]}" }
  action :nothing
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

execute "enable webrtc" do
  user "root"
  command "bbb-conf --enablewebrtc"
  action :nothing
  notifies :create, "template[sip.nginx]", :immediately
end

execute "clean bigbluebutton" do
  user "root"
  command "bbb-conf --clean"
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

service "nginx"

template "sip.nginx" do
  path "/etc/bigbluebutton/nginx/sip.nginx"
  source "sip.nginx.erb"
  mode "0644"
  variables(
    lazy {{ :external_ip => node[:bbb][:external_ip] }}
  )
  notifies :reload, "service[nginx]", :immediately
end

ruby_block "collect packages version" do
  block do
    packages = [ "bbb-*", node[:bbb][:bigbluebutton][:package_name], "ffmpeg", "libvpx" ]
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

ruby_block "reset flag restart" do
  block do
    node.set[:bbb][:force_restart] = false
  end
  only_if do node[:bbb][:force_restart] end
  notifies :run, "execute[restart bigbluebutton]", :delayed
end
    

ruby_block "reset flag setsalt" do
  block do
    node.set[:bbb][:enforce_salt] = nil
    node.set[:bbb][:setsalt_needed] = false
  end
  only_if do node[:bbb][:setsalt_needed] end
  notifies :run, "execute[set bigbluebutton salt]", :delayed
end

ruby_block "reset flag setip" do
  block do
    node.set[:bbb][:setip_needed] = false
  end
  only_if do node[:bbb][:setip_needed] end
  notifies :run, "execute[set bigbluebutton ip]", :delayed
end
