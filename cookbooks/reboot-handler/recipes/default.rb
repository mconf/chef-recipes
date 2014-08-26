# encoding: UTF-8
#
# Cookbook Name:: reboot-handler
# Recipe:: default
#
# Copyright 2012-2014, John Dewey
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'chef_handler'

handler = File.join(node['chef_handler']['handler_path'], 'reboot.rb')
cookbook_file(handler).run_action(:create)

##
# This was primarily done to prevent others from having to stub
# `include_recipe "reboot_handler"` inside ChefSpec.  ChefSpec
# doesn't seem to handle the following well on convergence.
begin
  require File.join node['chef_handler']['handler_path'], 'reboot'
rescue LoadError
  log 'Unable to require the reboot handler!' do
    action :write
  end
end

chef_handler 'Reboot' do
  source File.join node['chef_handler']['handler_path'], 'reboot.rb'
  supports report: true

  action :nothing
end.run_action(:enable)
