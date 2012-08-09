# Cookbook Name:: mconf-bbb
# Recipe:: deploy
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute

directory "#{node[:mconf][:bbb][:deploy_dir]}" do
  recursive true
  action :create
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node[:mconf][:bbb][:file]}" do
  source "#{node[:mconf][:bbb][:url]}"
  mode "0644"
end

execute "unzip_bigbluebutton" do
  user "root"
  command "unzip -o -d #{node[:mconf][:bbb][:deploy_dir]}/#{node[:mconf][:bbb][:version]} -q #{Chef::Config[:file_cache_path]}/#{node[:mconf][:bbb][:file]}"
  action :run
  only_if do File.exists?('#{node[:mconf][:bbb][:deploy_dir]}/.deploy_needed') end
end

timestamp = Time.new.strftime("%Y%m%d-%H%M%S")
backup_dir = "#{node[:mconf][:bbb][:deploy_dir]}/backup-#{timestamp}"

node[:bbb][:modules].each do |name|
  module_deploy_dir = node["bbb"]["#{name}"]["deploy_dir"]
  module_backup_dir = "#{backup_dir}/#{name}"
  
  directory "#{backup_dir}/#{name}" do
    recursive true
    action :create
    only_if do File.exists?('#{node[:mconf][:bbb][:deploy_dir]}/.deploy_needed') end
  end
  
  # backup only the bbb related apps on /usr/local/bin/
  if "#{name}" == "config"
    backup_files = "bbb-*"
  else
    backup_files = "*"
  end
  
  execute "backup_module" do
    user "root"
    command "cp -r #{module_deploy_dir}/#{backup_files} #{module_backup_dir}"
    action :run
    only_if do File.exists?('#{node[:mconf][:bbb][:deploy_dir]}/.deploy_needed') end
  end
  
  execute "deploy_module" do
    user "root"
    cwd "#{node[:mconf][:bbb][:deploy_dir]}"
    command "cp -r #{node[:mconf][:bbb][:version]}/#{name}/* #{module_deploy_dir}"
    action :run
    only_if do File.exists?('#{node[:mconf][:bbb][:deploy_dir]}/.deploy_needed') end
  end
end

#register deployed version
file "#{node[:mconf][:bbb][:deploy_dir]}/.deployed" do
  action :create
  content "#{node[:mconf][:bbb][:version]}"
end

#delete deploy flag after deployement
file "#{node[:mconf][:bbb][:deploy_dir]}/.deploy_needed" do
  action :delete
end

