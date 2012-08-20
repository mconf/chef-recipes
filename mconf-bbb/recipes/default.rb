# Cookbook Name:: mconf-bbb
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute

user "mconf" do
  action :create  
end

directory "#{node[:mconf][:bbb][:deploy_dir]}" do
  owner "mconf"
  group "mconf"
  recursive true
  action :create
end

include_recipe "bigbluebutton"

#check if a deploy is needed and set flag if necessary
file "#{node[:mconf][:bbb][:deploy_dir]}/.deploy_needed" do
    owner "mconf"
    group "mconf"
    action :nothing
    subscribes :create, resources("package[bigbluebutton]") , :immediately
end

file "#{node[:mconf][:bbb][:deploy_dir]}/.deploy_needed" do
    owner "mconf"
    group "mconf"
    action :create
    not_if do 
        File.exists?("#{node[:mconf][:bbb][:deploy_dir]}/.deployed") && File.read("#{node[:mconf][:bbb][:deploy_dir]}/.deployed") != "#{node[:mconf][:bbb][:version]}"
    end
end

ruby_block "define properties" do
    block do
        properties = Hash[File.read('/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties').scan(/(.+?)=(.+)/)]

        node.set[:bbb][:server_url] = properties["bigbluebutton.web.serverURL"]
        node.set[:bbb][:server_addr] = properties["bigbluebutton.web.serverURL"].gsub("http://", "")
        node.set[:bbb][:server_domain] = properties["bigbluebutton.web.serverURL"].gsub("http://", "").split(":")[0]
        node.set[:bbb][:salt] = properties["securitySalt"]
        
        Chef::Log.info("node[:bbb][:server_url] = #{node[:bbb][:server_url]}")
        Chef::Log.info("node[:bbb][:bbb][:server_addr] = #{node[:bbb][:server_addr]}")
        Chef::Log.info("node[:bbb][:server_domain] = #{node[:bbb][:server_domain]}")
        Chef::Log.info("node[:bbb][:bbb][:salt] = #{node[:bbb][:salt]}")
    end
end

include_recipe "live-notes-server"
include_recipe "mconf-bbb::deploy"

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

{ "bbb_api_conf.jsp" => "/var/lib/tomcat6/webapps/demo/bbb_api_conf.jsp",
  "bigbluebutton.properties" => "/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties" }.each do |k,v|
  template "#{v}" do
    source "#{k}"
    group "tomcat6"
    owner "tomcat6"
    mode "0644"
    variables(
      :server_url => node[:bbb][:server_url],
      :salt => node[:bbb][:salt]
    )
    # if the file is modified, restart tomcat
    notifies :restart, "service[tomcat6]", :delayed
  end
end

cookbook_file "/var/www/bigbluebutton-default/mconf-default.pdf" do
  source "mconf-default.pdf"
  mode "0644"
end

{ "bigbluebutton-sip.properties" => "/usr/share/red5/webapps/sip/WEB-INF/bigbluebutton-sip.properties" }.each do |k,v|
  template "#{v}" do
    source "#{k}"
    mode "0644"
    notifies :run, "execute[restart bigbluebutton]", :delayed
  end
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

