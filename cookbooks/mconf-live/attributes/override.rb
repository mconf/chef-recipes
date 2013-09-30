#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

override[:bbb][:ffmpeg][:install_method] = "package"
override[:bbb][:ffmpeg][:filename] = "ffmpeg_5:2.0.1-1_amd64.deb"
override[:bbb][:ffmpeg][:repo_url] = "http://dev.mconf.org/apt-repo/files"

override[:bbb][:libvpx][:install_method] = "package"
override[:bbb][:libvpx][:filename] = "libvpx_1.2.0-1_amd64.deb"
override[:bbb][:libvpx][:repo_url] = "http://dev.mconf.org/apt-repo/files"

override[:bbb][:openoffice][:repo_url] = "http://dev.mconf.org/apt-repo/files"

override[:bbb][:bigbluebutton][:repo_url] = "http://dev.mconf.org/apt-repo/ubuntu/stable"
override[:bbb][:bigbluebutton][:key_url] = "http://dev.mconf.org/apt-repo/mconf-public.gpg"
override[:bbb][:bigbluebutton][:components] = [ "lucid", "main" ]
override[:bbb][:bigbluebutton][:package_name] = "mconf-live"
