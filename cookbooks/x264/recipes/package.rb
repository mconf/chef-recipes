#
# Cookbook Name:: x264
# Recipe:: package
#
# Copyright 2014, Escape Studios
#

x264_packages.each do |pkg|
  package pkg do
    action :upgrade
  end
end
