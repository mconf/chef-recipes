#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

default[:mconf][:dir] = "/var/mconf"
default[:mconf][:live][:version] = "mconf-live0.2"
default[:mconf][:live][:version_int] = "2"
default[:mconf][:live][:file] = "#{node[:mconf][:live][:version]}.tar.gz"
default[:mconf][:live][:repo] = "http://mconf.org:8888/mconf-node"
default[:mconf][:live][:url] = "#{node[:mconf][:live][:repo]}/#{node[:mconf][:live][:file]}"
default[:mconf][:live][:deploy_dir] = "#{node[:mconf][:dir]}/deploy/mconf-live"
default[:mconf][:live][:force_deploy] = "false"
