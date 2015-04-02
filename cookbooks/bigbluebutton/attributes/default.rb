#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

default[:bbb][:ffmpeg][:install_method] = "source"
default[:bbb][:ffmpeg][:version] = "2.3.3"
default[:bbb][:ffmpeg][:filename] = nil
default[:bbb][:ffmpeg][:repo_url] = nil
default[:bbb][:ffmpeg][:dependencies] = []

default[:bbb][:libvpx][:install_method] = "source"
default[:bbb][:libvpx][:version] = "1.3.0"
default[:bbb][:libvpx][:filename] = nil
default[:bbb][:libvpx][:repo_url] = nil

apt_repo = "http://ubuntu.bigbluebutton.org/trusty-090"

default[:bbb][:bigbluebutton][:repo_url] = apt_repo
default[:bbb][:bigbluebutton][:key_url] = "http://ubuntu.bigbluebutton.org/bigbluebutton.asc"
default[:bbb][:bigbluebutton][:components] = ["bigbluebutton-trusty" , "main"]
default[:bbb][:bigbluebutton][:package_name] = "bigbluebutton"
default[:bbb][:bigbluebutton][:packages_version] = {}

default[:bbb][:recording][:rebuild] = []
default[:bbb][:recording][:playback_formats] = "presentation"
default[:bbb][:demo][:enabled] = false
default[:bbb][:check][:enabled] = false
default[:bbb][:ip] = nil
default[:bbb][:force_restart] = false
default[:bbb][:enforce_salt] = nil
default[:bbb][:keep_files_newer_than] = 5
