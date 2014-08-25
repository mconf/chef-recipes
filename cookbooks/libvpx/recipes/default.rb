#
# Cookbook Name:: libvpx
# Recipe:: default
#
# Copyright 2014, Escape Studios
#

case node['libvpx']['install_method']
when :source
  include_recipe 'libvpx::source'
when :package
  include_recipe 'libvpx::package'
end
