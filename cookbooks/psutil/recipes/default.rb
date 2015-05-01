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

%w{ python python-dev gcc }.each do |pkg|
  package pkg do
    action :install
  end
end

psutil_dir = "/usr/local/src/psutil"

git psutil_dir do
  repository "https://github.com/giampaolo/psutil.git"
  revision "release-0.5.1"
  action :sync
  # it is never notified
  # notifies :run, "execute[install psutil]", :immediately
end

execute "install psutil" do
    action :run
    user "root"
    cwd psutil_dir
    command "python setup.py install"
    creates "/usr/local/lib/python2.7/dist-packages/psutil-0.5.1.egg-info"
end
