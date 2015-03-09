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

apt_repo = "http://mconf-live-ci.nuvem.ufrgs.br/apt/production"

override[:bbb][:bigbluebutton][:repo_url] = apt_repo
override[:bbb][:bigbluebutton][:key_url] = "#{apt_repo}/../public.asc"
override[:bbb][:bigbluebutton][:components] = ["mconf-trusty" , "main"]
override[:bbb][:bigbluebutton][:package_name] = "mconf-live"

override[:bbb][:ffmpeg][:install_method] = "package"
override[:bbb][:ffmpeg][:version] = "2.4.2"
override[:bbb][:ffmpeg][:filename] = "ffmpeg_2.4.2-1_amd64.deb"
override[:bbb][:ffmpeg][:repo_url] = "#{apt_repo}/files"
override[:bbb][:ffmpeg][:dependencies] = [ "libwebp-dev" ]

override[:bbb][:libvpx][:install_method] = "package"
override[:bbb][:libvpx][:version] = "1.3.0"
override[:bbb][:libvpx][:filename] = "libvpx_1.3.0-1-trusty_amd64.deb"
override[:bbb][:libvpx][:repo_url] = "#{apt_repo}/files"

