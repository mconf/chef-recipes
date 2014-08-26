#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

override[:libvpx][:git_revision] = "v1.3.0"

override[:ffmpeg][:git_revision] = "n2.3.2"
override[:ffmpeg][:compile_flags] = [ "--enable-version3",
                                      "--enable-postproc",
                                      "--enable-libvorbis",
                                      "--enable-libvpx" ]
