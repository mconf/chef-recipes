#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

override[:ffmpeg][:compile_flags] = [ "--enable-x11grab",
                                      "--enable-gpl",
                                      "--enable-version3",
                                      "--enable-postproc",
                                      "--enable-libvorbis",
                                      "--enable-libvpx" ]

apt_repo = "http://dev.mconf.org/apt/ci-mconf-live"

override[:bbb][:bigbluebutton][:repo_url] = apt_repo
override[:bbb][:bigbluebutton][:key_url] = "#{apt_repo}/public.asc"
override[:bbb][:bigbluebutton][:components] = ["mconf-trusty" , "main"]
override[:bbb][:bigbluebutton][:package_name] = "mconf-live"
