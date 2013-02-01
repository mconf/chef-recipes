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
default[:mconf][:live][:repo] = "http://143.54.85.35:8888/mconf-node"
default[:mconf][:live][:url] = "#{node[:mconf][:live][:repo]}/#{node[:mconf][:live][:file]}"
default[:mconf][:live][:deploy_dir] = "#{node[:mconf][:dir]}/deploy/mconf-live"
default[:mconf][:live][:force_deploy] = false

# example of configuration for the Chef Server:
# remember the backslash before double quotes and backslash before backslash
# { "enabled": true, "meetingID": "Turing", "moderatorPW": "CHANGE-ME", "attendeePW": "INOFFENSIVE", "maxUsers": 100, "record": "true", "logoutURL": "https://docs.google.com/spreadsheet/viewform?formkey=dC1GX0dWMnFHWDVmS0F0QmprUDBaN1E6MA", "welcomeMsg": "Transmissão do ciclo de palestras sobre Alan Turing.<br><br>A gravação dessa sessão estará disponível posteriormente em <a href=\\\"event:http://mconf.org/events\\\"><u>http://mconf.org/events/turing</u></a>." }
default[:mconf][:streaming][:enabled] = false
default[:mconf][:streaming][:meetingID] = ""
default[:mconf][:streaming][:moderatorPW] = ""
default[:mconf][:streaming][:attendeePW] = ""
default[:mconf][:streaming][:maxUsers] = ""
default[:mconf][:streaming][:record] = ""
default[:mconf][:streaming][:logoutURL] = ""
default[:mconf][:streaming][:welcomeMsg] = ""
