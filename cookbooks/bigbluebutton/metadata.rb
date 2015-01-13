#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

name             "bigbluebutton"  
maintainer       "mconf"
maintainer_email "mconf@mconf.org"
license          "MPL v2.0"
description      "Installs a BigBlueButton server"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"
supports         "ubuntu", "= 14.04"
depends          "apt"
depends          "logrotate"
depends          "ffmpeg"
depends          "libvpx"
