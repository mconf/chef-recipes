#
# Cookbook Name:: x264
# Recipe:: default
#
# Copyright 2014, Escape Studios
#

case node['x264']['install_method']
when :source
  include_recipe 'x264::source'
when :package
  include_recipe 'x264::package'
end
