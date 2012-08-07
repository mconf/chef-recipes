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

include_recipe "bigbluebutton"

#check if a deploy is needed and set flag if necessary
file "#{node[:mconf][:bbb][:deploy_dir]}/deploy_needed" do
    owner "mconf"
    group "mconf"
    mode "0755"
    action :nothing
    subscribes :create, resources("package[bigbluebutton]") , :immediately
end

file "#{node[:mconf][:bbb][:deploy_dir]}/deploy_needed" do
    owner "mconf"
    group "mconf"
    mode "0755"
    action :nothing
    only_if do 
        File.exists?("#{node[:mconf][:bbb][:deploy_dir]}/.deployed") && File.read("#{node[:mconf][:bbb][:deploy_dir]}/.deployed") != "#{node[:mconf][:bbb][:version]}"
    #File.open("#{node[:mconf][:bbb][:deploy_dir]}/.deployed", "r").read != "#{node[:mconf][:bbb][:version]}"
    end
end

ruby_block "debug" do
    block do
        if File.exists?("#{node[:mconf][:bbb][:deploy_dir]}/.deployed")
            log File.open("#{node[:mconf][:bbb][:deploy_dir]}/.deployed", "r").read
        end
        log "#{node[:mconf][:bbb][:version]}"
    end
end

include_recipe "mconf-bbb::deploy"

ruby_block "define_properties" do
    block do
        properties = Hash[File.read('/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties').scan(/(.+?)=(.+)/)]

        node.set[:bbb][:server_url] = properties["bigbluebutton.web.serverURL"]
        node.set[:bbb][:server_domain] = properties["bigbluebutton.web.serverURL"].gsub("http://", "").split(":")[0]
        node.set[:bbb][:salt] = properties["securitySalt"]
    end
end

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
    :salt => node[:bbb][:salt]
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

