#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

override[:libvpx][:git_revision] = "b9ce43029298182668d4dcb0e0814189e4a63c2a" # tag v1.2.0

override[:ffmpeg][:git_revision] = "b06903e6c56d2e08c3b79f67a1e81e24e90c60ac" # tag n0.11.2
override[:ffmpeg][:compile_flags] = [ "--enable-version3",
                                      "--enable-postproc",
                                      "--enable-libopencore-amrnb",
                                      "--enable-libopencore-amrwb",
                                      "--enable-libtheora",
                                      "--enable-libvorbis",
                                      "--enable-libvpx",
                                      "--disable-debug",
                                      "--enable-pthreads" ]

override[:yasm][:install_method] = "source"
override[:yasm][:git_revision] = "0f5e8ebdb5a273d8fd61e00e90d0c9778b7814cf" # tag v1.2.0
