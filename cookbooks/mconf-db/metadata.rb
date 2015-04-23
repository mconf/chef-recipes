#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

name             "mconf-db"
maintainer       "mconf"
maintainer_email "mconf@mconf.org"
license          "MPL v2.0"
description      "Sets up an instance of the database used by Mconf"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.0.1"
depends          "mysql2_chef_gem", "~> 1.0"
depends          "mysql", "~> 6.0"
depends          "database", "~> 4.0"

recipe "mconf-db::default", "Sets up an instance of the database used by Mconf"
