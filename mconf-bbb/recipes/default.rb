# Cookbook Name:: mconf-bbb
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute

include_recipe "live-notes-server"

directory "#{node[:mconf][:bbb][:deploy_dir]}" do
  recursive true
  action :create
end

node.set[:tmp][:mconf_bbb][:current_pkg_version] = ""
node.set[:tmp][:mconf_bbb][:current_deployed_version] = ""
node.set[:tmp][:mconf_bbb][:deploy_needed] = false

ruby_block "save_current_version" do
  block do
    current_pkg_version = ""
    if File.exists?("#{node[:mconf][:bbb][:deploy_dir]}/.installed_packages")
      File.open("#{node[:mconf][:bbb][:deploy_dir]}/.installed_packages", "r") do |f|
        while line = f.gets
          current_pkg_version += line
        end
      end
    else
      Chef::Log.debug("The file containing the current installed packages version doesn't exists: #{node[:mconf][:bbb][:deploy_dir]}/.installed_packages");
    end

    current_deployed_version = ""
    if File.exists?("#{node[:mconf][:bbb][:deploy_dir]}/.deployed")
      File.open("#{node[:mconf][:bbb][:deploy_dir]}/.deployed", "r") do |f|
        while line = f.gets
          current_deployed_version += line
        end
      end
    else
      Chef::Log.debug("The file containing the current deployed version doesn't exists: #{node[:mconf][:bbb][:deploy_dir]}/.deployed");
    end
    
    node.set[:tmp][:mconf_bbb][:current_pkg_version] = current_pkg_version
    node.set[:tmp][:mconf_bbb][:current_deployed_version] = current_deployed_version
#    node.save

    Chef::Log.debug("Current packages version: #{node[:tmp][:mconf_bbb][:current_pkg_version]}")
    Chef::Log.debug("Current deployed version: #{node[:tmp][:mconf_bbb][:current_deployed_version]}")
  end
  action :create
end

include_recipe "bigbluebutton"

ruby_block "check_deploy_needed" do
  block do
    def bigbluebutton_packages_version()
      pkg_version = ""
      %w{ bigbluebutton bbb-config bbb-common bbb-web bbb-client bbb-apps bbb-apps-sip bbb-apps-video bbb-apps-deskshare bbb-playback-slides bbb-openoffice-headless bbb-record-core }.each do |pkg|
        pkg_version += `dpkg -s #{pkg} | grep 'Version' | sed 's:.*\\: \\(.*\\):#{pkg} \\1:g'`
      end
      return pkg_version
    end

    node.set[:tmp][:mconf_bbb][:new_pkg_version] = bigbluebutton_packages_version()
    node.set[:tmp][:mconf_bbb][:deploy_needed] = (node[:tmp][:mconf_bbb][:current_pkg_version] != node[:tmp][:mconf_bbb][:new_pkg_version]) or (node[:tmp][:mconf_bbb][:current_deployed_version] != node[:mconf][:bbb][:version])
#    node.save
    
    Chef::Log.debug("New packages version: #{node[:tmp][:mconf_bbb][:new_pkg_version]}")
    Chef::Log.debug("Deploy needed? #{node[:tmp][:mconf_bbb][:deploy_needed]}")
  end
  action :create
end

log "Deploy needed (second check)? #{node[:tmp][:mconf_bbb][:deploy_needed]}"

if node[:tmp][:mconf_bbb][:deploy_needed]
  include_recipe "mconf-bbb::deploy"
  File.open("#{node[:mconf][:bbb][:deploy_dir]}/.installed_packages", "w") do |f|
    f.write("#{node[:tmp][:mconf_bbb][:new_pkg_version]}")
  end
  File.open("#{node[:mconf][:bbb][:deploy_dir]}/.deployed", "w") do |f|
    f.write("#{node[:mconf][:bbb][:version]}")
  end
else
  log "There's no need to deploy again the custom version of BigBlueButton"
end

properties = Hash[File.read('/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties').scan(/(.+?)=(.+)/)]

node.set[:bbb][:server_url] = properties["bigbluebutton.web.serverURL"]
node.set[:bbb][:server_domain] = properties["bigbluebutton.web.serverURL"].gsub("http://", "").split(":")[0]
node.set[:bbb][:salt] = properties["securitySalt"]

service "tomcat6"

template "/var/www/bigbluebutton/client/conf/config.xml" do
  source "config.xml"
  mode "0644"
  variables(
    :server_url => node[:bbb][:server_url],
    :server_domain => node[:bbb][:server_domain],
    :module_version => node[:mconf][:bbb][:version_int]
  )
end

template "/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties" do
  source "bigbluebutton.properties"
  group "tomcat6"
  owner "tomcat6"
  mode "0644"
  variables(
    :server_url => node[:bbb][:server_url],
    :salt => node.set[:bbb][:salt]
  )
  # if the file is modified, restart tomcat
  notifies :restart, "service[tomcat6]", :immediately
end


cookbook_file "/var/www/bigbluebutton-default/mconf-default.pdf" do
  source "mconf-default.pdf"
  mode "0644"
end

template "/usr/share/red5/webapps/sip/WEB-INF/bigbluebutton-sip.properties" do
  source "bigbluebutton-sip.properties"
  mode "0644"
end

cookbook_file "/opt/freeswitch/conf/vars.xml" do
  source "vars.xml"
  group "daemon"
  owner "freeswitch"
  mode "0755"
end

cookbook_file "/opt/freeswitch/conf/sip_profiles/external.xml" do
  source "external.xml"
  group "daemon"
  owner "freeswitch"
  mode "0755"
end

cookbook_file "/opt/freeswitch/conf/autoload_configs/conference.conf.xml" do
  source "conference.conf.xml"
  group "daemon"
  owner "freeswitch"
  mode "0755"
end

