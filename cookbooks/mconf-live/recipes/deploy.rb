#
# Cookbook Name:: mconf-live
# Recipe:: deploy
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

execute "bbb-conf --stop" do
  user "root"
  action :run
  only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

if "#{node[:mconf][:live][:repo]}".start_with? "http://"
  remote_file "#{Chef::Config[:file_cache_path]}/#{node[:mconf][:live][:file]}" do
    source "#{node[:mconf][:live][:url]}"
    mode "0644"
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
  end
else
  # this is a workaround to be able to install Mconf-Live from a local file instead of a remote one
  FileUtils.cp "#{node[:mconf][:live][:url]}", "#{Chef::Config[:file_cache_path]}/#{node[:mconf][:live][:file]}"
end

execute "untar mconf-live" do
  user "#{node[:mconf][:user]}"
  cwd "#{Chef::Config[:file_cache_path]}"
  command "tar xzf #{node[:mconf][:live][:file]} --directory #{node[:mconf][:live][:deploy_dir]}/"
  action :run
  only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy apps" do
    block do
        %w{ bigbluebutton video deskshare sip }.each do |app|
            if File.exists?("#{node[:mconf][:live][:deploy_dir]}/apps/#{app}")
                Chef::Log.info("Deploying red5 app: #{app}")
                FileUtils.remove_entry_secure "/usr/share/red5/webapps/#{app}", :force => true, :verbose => true
                FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/apps/#{app}", "/usr/share/red5/webapps/"
            end
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy client" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/client")
            Chef::Log.info("Deploying client")
            FileUtils.remove_entry_secure "/var/www/bigbluebutton/client/", :force => true, :verbose => true
            FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/client", "/var/www/bigbluebutton/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy config" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/config")
            Chef::Log.info("Deploying config")
            FileUtils.cp_r Dir.glob("#{node[:mconf][:live][:deploy_dir]}/config/*"), "/usr/local/bin/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy demo" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/demo") && File.exists?("/var/lib/tomcat6/webapps/demo/")
            Chef::Log.info("Deploying demo")
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/demo.war", :force => true, :verbose => true
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/demo/", :force => true, :verbose => true
            FileUtils.cp_r Dir.glob("#{node[:mconf][:live][:deploy_dir]}/demo/*"), "/var/lib/tomcat6/webapps/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy web" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/web") && File.exists?("/var/lib/tomcat6/webapps/bigbluebutton/")
            Chef::Log.info("Deploying bigbluebutton-web")
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/bigbluebutton.war", :force => true, :verbose => true
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/bigbluebutton/", :force => true, :verbose => true
            FileUtils.cp_r Dir.glob("#{node[:mconf][:live][:deploy_dir]}/web/*"), "/var/lib/tomcat6/webapps/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "sleep until bigbluebutton-web is deployed" do
  block do
    %x(service tomcat6 start)
    count = 15
    while not File.exists?("/var/lib/tomcat6/webapps/bigbluebutton") and count > 0 do
      sleep 1.0
      count -= 1
    end
  end
  only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

# register deployed version
file "#{node[:mconf][:live][:deploy_dir]}/.deployed" do
  action :create
  content "#{node[:mconf][:live][:version]}"
end

# restore salt and IP
execute "bbb-conf --setsalt #{node[:bbb][:salt]} && bbb-conf --setip #{node[:bbb][:server_addr]}" do
    user "root"
    action :run
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
    notifies :run, "execute[restart bigbluebutton]", :delayed
end

