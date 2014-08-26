#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

mconf_dir = "/var/mconf"

default[:mconf][:user] = "mconf"
default[:mconf][:dir] = mconf_dir
default[:mconf][:tools][:dir] = "#{mconf_dir}/tools"
default[:mconf][:log][:dir] = "#{mconf_dir}/log"

# set true if you want your Mconf-Live server to act as a standalone server or 
# if you want a recording server that will query for encrypted recordings
default[:mconf][:recording_server][:enabled] = false
default[:mconf][:recording_server][:private_key_path] = "#{mconf_dir}/private_key.pem"
default[:mconf][:recording_server][:get_recordings_url] = nil

# example of configuration for the Chef Server:
# remember the backslash before double quotes and backslash before backslash
=begin
{
  "enabled": true, 
  "meetingID": "Turing", 
  "moderatorPW": "CHANGE-ME", 
  "attendeePW": "INOFFENSIVE", 
  "maxUsers": 100, 
  "record": "true", 
  "logoutURL": "https://docs.google.com/spreadsheet/viewform?formkey=dC1GX0dWMnFHWDVmS0F0QmprUDBaN1E6MA", 
  "welcomeMsg": "Transmissão do ciclo de palestras sobre Alan Turing.<br><br>A gravação dessa sessão estará disponível posteriormente em <a href=\\\"event:http://mconf.org/events\\\"><u>http://mconf.org/events/turing</u></a>." 
}
=end
default[:mconf][:streaming][:enabled] = false
default[:mconf][:streaming][:meetingID] = ""
default[:mconf][:streaming][:moderatorPW] = ""
default[:mconf][:streaming][:attendeePW] = ""
default[:mconf][:streaming][:maxUsers] = ""
default[:mconf][:streaming][:record] = ""
default[:mconf][:streaming][:logoutURL] = ""
default[:mconf][:streaming][:welcomeMsg] = ""
default[:mconf][:streaming][:metadata] = {}

default[:mconf][:branding][:logo] = ""
default[:mconf][:branding][:copyright_message] = ""
default[:mconf][:branding][:background] = ""
