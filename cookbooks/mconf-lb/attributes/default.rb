#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

default["db"]["name"] = "mconf_lb_production"
default["db"]["user"] = "mconf"
default["db"]["passwords"]["root"] = "ilikerandompasswords"
default["db"]["passwords"]["repl"] = "ilikerandompasswords"
default["db"]["passwords"]["app"] = "ilikerandompasswords"

default["mconf"]["user"] = "mconf"

default["mconf-lb"]["domain"] = "lb.mconf.com"
default["mconf-lb"]["deploy_to"] = "/var/www/mconf-lb"
