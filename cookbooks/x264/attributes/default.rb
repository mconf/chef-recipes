#
# Cookbook Name:: x264
# Attributes:: default
#
# Copyright 2014, Escape Studios
#

default['x264']['install_method'] = :source
default['x264']['git_repository'] = 'git://git.videolan.org/x264.git'
default['x264']['prefix'] = '/usr/local'
default['x264']['compile_flags'] = ['--enable-static']
default['x264']['git_revision'] = 'stable'
