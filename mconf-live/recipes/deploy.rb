# Cookbook Name:: mconf-live
# Recipe:: deploy
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute

directory "#{node[:mconf][:live][:deploy_dir]}" do
    owner "mconf"
    group "mconf"
    recursive true
    action :create
end

execute "bbb-conf --stop" do
  user "root"
  action :run
  only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node[:mconf][:live][:file]}" do
  source "#{node[:mconf][:live][:url]}"
  mode "0644"
end

execute "untar mconf-live" do
  user "mconf"
  cwd "#{Chef::Config[:file_cache_path]}"
  command "tar xzf #{node[:mconf][:live][:file]} --directory #{node[:mconf][:live][:deploy_dir]}/"
  action :run
  only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy apps" do
    block do
        %w{ "bigbluebutton" "video" "deskshare" "sip" }.each do |app|
            if File.exists?("#{node[:mconf][:live][:deploy_dir]}/apps/#{app}")
                FileUtils.remove_entry_secure "/usr/share/red5/webapps/#{app}", :force => true
                FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/apps/#{app}", "/usr/share/red5/webapps/"
            end
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy client" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/client")
            FileUtils.remove_entry_secure "/var/www/bigbluebutton/client", :force => true
            FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/client", "/var/www/bigbluebutton/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy config" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/config")
            FileUtils.cp_r Dir.glob("#{node[:mconf][:live][:deploy_dir]}/config/*"), "/usr/local/bin/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy demo" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/demo") && File.exists?("/var/lib/tomcat6/webapps/demo/")
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/demo.war", :force => true
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/demo", :force => true
            FileUtils.cp_r Dir.glob("#{node[:mconf][:live][:deploy_dir]}/demo/*"), "/var/lib/tomcat6/webapps/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy web" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/web") && File.exists?("/var/lib/tomcat6/webapps/bigbluebutton/")
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/bigbluebutton.war", :force => true
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/bigbluebutton", :force => true
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

#register deployed version
file "#{node[:mconf][:live][:deploy_dir]}/.deployed" do
  action :create
  content "#{node[:mconf][:live][:version]}"
end

execute "bbb-conf --setsalt #{node[:bbb][:salt]} && bbb-conf --setip #{node[:bbb][:server_addr]}" do
    user "root"
    action :run
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
    notifies :run, "execute[restart bigbluebutton]", :delayed
end

#delete deploy flag after deployement
file "#{node[:mconf][:live][:deploy_dir]}/.deploy_needed" do
    action :delete
end

