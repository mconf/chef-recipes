# Cookbook Name:: mconf-live
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute

directory "#{node[:mconf][:live][:deploy_dir]}" do
  owner "#{node[:mconf][:user]}"
  recursive true
  action :create
end

include_recipe "bigbluebutton"
include_recipe "live-notes-server"

t = ruby_block "print conditions to deploy" do
    block do
        Chef::Log.info("Force deploy? #{node[:mconf][:live][:force_deploy]}")
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deployed")
            Chef::Log.info(".deployed content? " + File.read("#{node[:mconf][:live][:deploy_dir]}/.deployed"))
        else
            Chef::Log.info(".deployed doesn't exist")
        end
        Chef::Log.info("Version to deploy? #{node[:mconf][:live][:version]}")
    end
    action :create
end

Chef::Log.info("Printed during Ruby pass:")
t.run_action(:create)

# conditions to trigger the deploy procedure
# - forced by an attribute
# - deployed version file doesn't exist
# - file exists but the deployed version is different than the current version
file "create deploy flag" do
    path "#{node[:mconf][:live][:deploy_dir]}/.deploy_needed"
    owner "#{node[:mconf][:user]}"
    action :create
    only_if do "#{node[:mconf][:live][:force_deploy]}" == "true" or not File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deployed") or (File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deployed") and File.read("#{node[:mconf][:live][:deploy_dir]}/.deployed") != "#{node[:mconf][:live][:version]}") end
    subscribes :create, resources("package[bigbluebutton]"), :immediately
end

include_recipe "mconf-live::deploy"

# delete deploy flag after deployement
file "delete flag after the deploy" do
    path "#{node[:mconf][:live][:deploy_dir]}/.deploy_needed"
    action :delete
end

service "tomcat6"

template "/var/www/bigbluebutton/client/conf/config.xml" do
  source "config.xml.erb"
  mode "0644"
  variables(
    :server_url => node[:bbb][:server_url],
    :server_domain => node[:bbb][:server_domain],
    :module_version => node[:mconf][:live][:version_int]
  )
end

{ "bbb_api_conf.jsp.erb" => "/var/lib/tomcat6/webapps/demo/bbb_api_conf.jsp",
  "bigbluebutton.properties.erb" => "/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties" }.each do |k,v|
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
    only_if do File.exists?(File.dirname("#{v}")) end
  end
end

cookbook_file "/var/www/bigbluebutton-default/mconf-default.pdf" do
  source "mconf-default.pdf"
  mode "0644"
end

{ "bigbluebutton-sip.properties.erb" => "/usr/share/red5/webapps/sip/WEB-INF/bigbluebutton-sip.properties" }.each do |k,v|
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
