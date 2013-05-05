#
# Cookbook Name:: mconf-live
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

# the streaming system needs the BigBlueButton demo installed
if node[:mconf][:streaming][:enabled]
  node.set[:bbb][:demo][:enabled] = true
end

directory node[:mconf][:live][:deploy_dir] do
  owner node[:mconf][:user]
  recursive true
  action :create
  subscribes :create, resources("package[bigbluebutton]"), :immediately
  subscribes :create, resources("package[bbb-demo]"), :immediately
end

ruby_block "print conditions to deploy during execution phase" do
    block do
        Chef::Log.info("This is being printed on execution phase")
    end
    action :create
end  

t = ruby_block "print conditions to deploy" do
    block do
        Chef::Log.info("\tForce deploy? #{node[:mconf][:live][:force_deploy]}")
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deployed")
            Chef::Log.info("\t.deployed content? " + File.read("#{node[:mconf][:live][:deploy_dir]}/.deployed"))
        else
            Chef::Log.info("\t.deployed doesn't exist")
        end
        Chef::Log.info("\tVersion to deploy? #{node[:mconf][:live][:version]}")
    end
    action :create
end

Chef::Log.info("This is being printed on compile phase")
t.run_action(:create)

# conditions to trigger the deploy procedure
# - forced by an attribute
# - deployed version file doesn't exist
# - file exists but the deployed version is different than the current version
file "create deploy flag" do
    path "#{node[:mconf][:live][:deploy_dir]}/.deploy_needed"
    owner node[:mconf][:user]
    action :create
    only_if do node[:mconf][:live][:force_deploy] or not File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deployed") or (File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deployed") and File.read("#{node[:mconf][:live][:deploy_dir]}/.deployed") != node[:mconf][:live][:version]) end
    subscribes :create, resources("package[bigbluebutton]"), :immediately
    subscribes :create, resources("package[bbb-demo]"), :immediately
end

ruby_block "print deploy flag" do
    block do
        Chef::Log.info("\tDeploy needed? #{File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed")}")
    end
    action :create
end

include_recipe "mconf-live::deploy" unless node[:bbb][:handling_meetings]

# delete deploy flag after deployement
file "delete flag after the deploy" do
    path "#{node[:mconf][:live][:deploy_dir]}/.deploy_needed"
    action :delete
end

# restart only tomcat doesn't work because doing it BigBlueButton API doesn't 
# find anymore the running meetings
#service "tomcat6"

template "/var/www/bigbluebutton/client/conf/config.xml" do
  source "config.xml.erb"
  mode "0644"
  variables(
    :module_version => node[:mconf][:live][:version_int],
    :streaming => node[:mconf][:streaming][:enabled]
  )
end

{ "bbb_api_conf.jsp.erb" => "/var/lib/tomcat6/webapps/demo/bbb_api_conf.jsp",
  "bigbluebutton.properties.erb" => "/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties",
  "bigbluebutton.yml.erb" => "/usr/local/bigbluebutton/core/scripts/bigbluebutton.yml" }.each do |k,v|
  template v do
    source k
    group "tomcat6"
    owner "tomcat6"
    mode "0644"
    variables(
      :server_url => node[:bbb][:server_url],
      :salt => node[:bbb][:salt]
    )
    notifies :run, "execute[restart bigbluebutton]", :delayed
    only_if do File.exists?(File.dirname(v)) end
  end
end

{ "mconf-default.pdf" => "/var/www/bigbluebutton-default/mconf-default.pdf",
  "layout.xml" => "/var/www/bigbluebutton/client/conf/layout.xml",
  "layout-streaming.xml" => "/var/www/bigbluebutton/client/conf/layout-streaming.xml" }.each do |k,v|
    cookbook_file v do
      source k
      mode "0644"
    end
end

service "nginx"

cookbook_file "/etc/nginx/mime.types" do
    source "nginx-mime.types"
    mode "0644"
    notifies :restart, "service[nginx]", :immediately
end

template "/var/lib/tomcat6/webapps/demo/mconf_event_conf.jsp" do
  source "mconf_event_conf.jsp.erb"
  group "tomcat6"
  owner "tomcat6"
  mode "0644"
  variables(
    :meetingID => node[:mconf][:streaming][:meetingID],
    :moderatorPW => node[:mconf][:streaming][:moderatorPW],
    :attendeePW => node[:mconf][:streaming][:attendeePW],
    :maxUsers => node[:mconf][:streaming][:maxUsers],
    :record => node[:mconf][:streaming][:record],
    :logoutURL => node[:mconf][:streaming][:logoutURL],
    :welcomeMsg => node[:mconf][:streaming][:welcomeMsg],
    :metadata => node[:mconf][:streaming][:metadata]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
  only_if do File.exists?("/var/lib/tomcat6/webapps/demo/") and node[:mconf][:streaming][:enabled] end
end

cookbook_file "/var/lib/tomcat6/webapps/demo/mconf_event.jsp" do
  source "mconf_event.jsp"
  group "tomcat6"
  owner "tomcat6"
  mode "0644"
  notifies :run, "execute[restart bigbluebutton]", :delayed
  only_if do File.exists?("/var/lib/tomcat6/webapps/demo/") and node[:mconf][:streaming][:enabled] end
end

if not node[:mconf][:streaming][:enabled]
  [ "/var/lib/tomcat6/webapps/demo/mconf_event.jsp", 
    "/var/lib/tomcat6/webapps/demo/mconf_event_conf.jsp"].each do |f|
      file f do
        action :delete
      end
  end
end

{ "bigbluebutton-sip.properties.erb" => "/usr/share/red5/webapps/sip/WEB-INF/bigbluebutton-sip.properties" }.each do |k,v|
  template v do
    source k
    mode "0644"
    notifies :run, "execute[restart bigbluebutton]", :delayed
  end
end

cookbook_file "/var/www/bigbluebutton-default/index.html" do
  if node[:bbb][:demo][:enabled]
    source "index-demo-enabled.html"
  else
    source "index-demo-disabled.html"
  end
  mode "0644"
end

[
  "/var/bigbluebutton/playback/",
  "/var/bigbluebutton/recording/raw/",
  "/var/bigbluebutton/recording/process/",
  "/var/bigbluebutton/recording/publish/",
  "/var/bigbluebutton/recording/status/recorded/",
  "/var/bigbluebutton/recording/status/archived/",
  "/var/bigbluebutton/recording/status/processed/",
  "/var/bigbluebutton/recording/status/sanity/"
].each do |dir|
    directory dir do
        owner "tomcat6"
        group "tomcat6"
        recursive true
        action :create
    end
end

directory "/var/bigbluebutton/deskshare/" do
    owner "red5"
    group "red5"
    recursive true
    action :create
end

directory "/var/bigbluebutton/meetings/" do
    owner "freeswitch"
    group "daemon"
    recursive true
    action :create
end
