#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#default[:nsca][:version] = "2.9.1"
default[:nsca][:version] = "2.7.2"
default[:nsca][:dir] = "/usr/local/nagios/bin"
default[:nsca][:config_dir] = "/usr/local/nagios/etc"
default[:nsca][:force_reinstall] = false
default[:nsca][:timeout] = 5