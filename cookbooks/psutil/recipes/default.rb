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

psutil_version = "1400"
psutil_version_installed = "nil"
if File.exists?("#{Chef::Config[:file_cache_path]}/psutil")
    psutil_version_installed = `svn info #{Chef::Config[:file_cache_path]}/psutil/ | grep 'Revision: ' | cut -d' ' -f2`.strip!
end

Chef::Log.info("psutil revision to be installed: #{psutil_version}")
Chef::Log.info("psutil revision currently installed: #{psutil_version_installed}")
if psutil_version != psutil_version_installed
    Chef::Log.info("psutil revision will be updated")
end

subversion "#{Chef::Config[:file_cache_path]}/psutil" do
    repository "http://psutil.googlecode.com/svn/trunk"
    revision psutil_version
    action :sync
    only_if do psutil_version != psutil_version_installed end
end

execute "install psutil" do
    action :run
    user "root"
    cwd "#{Chef::Config[:file_cache_path]}/psutil"
    command "python setup.py install"
    creates "/usr/local/lib/python2.6/dist-packages/psutil-0.5.1.egg-info"
end
