#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

maintainer       "mconf"
maintainer_email "mconf@mconf.org"
license          "MPL v2.0"
description      "Installs a specific bbb server for a mconf-node"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.0.3"
supports         "ubuntu", "= 10.04"
depends          "ruby-1.9.2"
depends          "apt"
depends          "logrotate"
