#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

name             "mconf-live"
maintainer       "mconf"
maintainer_email "mconf@mconf.org"
license          "MPL v2.0"
description      "Install Mconf-Live, the Mconf fork of BigBlueButton"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.0.2"
supports         "ubuntu", "= 10.04"
depends          "bigbluebutton"
