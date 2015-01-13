#
# Cookbook Name:: x264
# Recipe:: source
#
# Copyright 2014, Escape Studios
#

include_recipe 'build-essential'
include_recipe 'git'
include_recipe 'yasm'

x264_packages.each do |pkg|
  package pkg do
    action :purge
    ignore_failure true
  end
end

creates_x264 = "#{node['x264']['prefix']}/bin/x264"

file creates_x264 do
  action :nothing
end

git "#{Chef::Config[:file_cache_path]}/x264" do
  repository node['x264']['git_repository']
  reference node['x264']['git_revision']
  action :sync
  notifies :delete, "file[#{creates_x264}]", :immediately
end

# Write the flags used to compile the application to disk. If the flags
# do not match those that are in the compiled_flags attribute - we recompile
template "#{Chef::Config[:file_cache_path]}/x264-compiled_with_flags" do
  source 'compiled_with_flags.erb'
  owner 'root'
  group 'root'
  mode 0600
  variables(
    :compile_flags => node['x264']['compile_flags']
  )
  notifies :delete, "file[#{creates_x264}]", :immediately
end

bash 'compile_x264' do
  cwd "#{Chef::Config[:file_cache_path]}/x264"
  code <<-EOH
    ./configure --prefix=#{node['x264']['prefix']} #{node['x264']['compile_flags'].join(' ')}
    make clean && make && make install
  EOH
  creates creates_x264
end
