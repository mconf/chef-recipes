#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

default['mconf-web']['db']['name'] = 'mconf_production'
default['mconf-web']['db']['user'] = 'mconf'
default['mconf-web']['db']['passwords']['root'] = 'password'
default['mconf-web']['db']['passwords']['repl'] = 'password'
default['mconf-web']['db']['passwords']['app'] = 'password'

default['mconf']['user'] = 'mconf'

default['mconf-web']['domain'] = '192.168.0.100'
default['mconf-web']['deploy_to'] = '/var/www/mconf-web/current'
