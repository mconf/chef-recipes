#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

default[:bbb][:recording][:video] = true
default[:bbb][:recording][:deskshare] = true
default[:bbb][:demo][:enabled] = false
default[:bbb][:ip] = nil
default[:bbb][:force_restart] = false
default[:bbb][:enforce_salt] = nil
default[:bbb][:keep_files_newer_than] = 14
default[:bbb][:enable_comfort_noise] = false
# enable or disable FreeSWITCH sounds:
# "You are now muted"
# "You are now unmuted"
# "You are currently the only person in this conference"
default[:bbb][:enable_freeswitch_sounds] = false
default[:bbb][:enable_freeswitch_alone_music] = false
#default[:bbb][:version] = "0.80ubuntu4"
#default[:bbb_demo][:version] = "0.80ubuntu76"

default[:red5][:user] = "red5"
default[:red5][:group] = "red5"
default[:red5][:home] = "/usr/share/red5"
default[:freeswitch][:user] = "freeswitch"
default[:freeswitch][:group] = "daemon"
default[:freeswitch][:home] = "/opt/freeswitch"
