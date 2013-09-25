#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

default[:bbb][:ffmpeg][:install_method] = "source"
default[:bbb][:ffmpeg][:version] = "2.0.1"
default[:bbb][:ffmpeg][:filename] = nil
default[:bbb][:ffmpeg][:repo_url] = nil

default[:bbb][:libvpx][:install_method] = "source"
default[:bbb][:libvpx][:version] = "1.2.0"
default[:bbb][:libvpx][:filename] = nil
default[:bbb][:libvpx][:repo_url] = nil

default[:bbb][:openoffice][:filename] = "openoffice.org_1.0.4_all.deb"
default[:bbb][:openoffice][:repo_url] = nil

default[:bbb][:bigbluebutton][:repo_url] = "http://ubuntu.bigbluebutton.org/lucid_dev_081"
default[:bbb][:bigbluebutton][:key_url] = "http://ubuntu.bigbluebutton.org/bigbluebutton.asc"
default[:bbb][:bigbluebutton][:components] = ["bigbluebutton-lucid" , "main"]
default[:bbb][:bigbluebutton][:package_name] = "bigbluebutton"

default[:bbb][:recording][:video] = true
default[:bbb][:recording][:deskshare] = true
default[:bbb][:recording][:rebuild] = []
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

default[:bbb][:recording][:presentation][:video_output_width] = 320
default[:bbb][:recording][:presentation][:video_output_height] = 240
default[:bbb][:recording][:presentation][:audio_offset] = 0
default[:bbb][:recording][:presentation][:include_deskshare] = true
