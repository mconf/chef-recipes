#
# Cookbook Name:: yasm
# Attributes:: default
#
# Copyright 2012-2014, Escape Studios
#

default['yasm']['install_method'] = 'package'
default['yasm']['prefix'] = '/usr'
default['yasm']['git_repository'] = 'git://github.com/yasm/yasm.git'
default['yasm']['git_revision'] = 'HEAD'
default['yasm']['compile_flags'] = []
