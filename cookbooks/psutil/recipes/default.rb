#
# Cookbook Name:: psutil
# Recipe:: default
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

%w{ python python-dev subversion gcc }.each do |pkg|
  package pkg do
    action :install
  end
end

directory "#{Chef::Config[:file_cache_path]}/psutil" do
  owner "root"
  recursive true
end

subversion "get psutil source code" do
    repository "http://psutil.googlecode.com/svn/trunk"
#    revision "HEAD"
    revision "1400"
    destination "#{Chef::Config[:file_cache_path]}/psutil/"
    action :sync
    notifies :run, 'execute[install psutil]', :immediately
end

execute "install psutil" do
    action :nothing
    user "root"
    cwd "#{Chef::Config[:file_cache_path]}/psutil/"
    command "python setup.py install"
end
