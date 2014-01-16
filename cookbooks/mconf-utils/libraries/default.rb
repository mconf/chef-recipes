#
# Cookbook Name:: mconf-node
# Library:: default
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

def chef_daemon_process()
  `ps aux | grep 'ruby.*chef-client -i' | grep -v 'grep'`.strip!
end

def chef_daemon_is_running()
  not chef_daemon_process().nil?
end
