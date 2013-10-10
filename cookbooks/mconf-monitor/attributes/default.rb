#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

default[:mconf][:tools][:dir] = "/var/mconf/tools"
default[:mconf][:instance_type] = "bigbluebutton"
default[:mconf][:interval] = "20"
default[:mconf][:nagios][:dir] = "#{node[:mconf][:tools][:dir]}/nagios"
# it should be a list, ex: ["server1","server2"]
# if nil, it will use the attribute node[:nsca_handler][:nsca_server] instead
default[:mconf][:monitor][:servers] = nil
# if you want to force restart on every execution, set normal[:mconf][:monitor][:force_restart] = true
default[:mconf][:monitor][:force_restart] = false

# this is to store the topology
default[:mconf][:topology] = {}
default[:mconf][:remount_topology] = false
default[:mconf][:as_lookup] = nil
