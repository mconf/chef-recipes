#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

# User and group on the server the application is being deployed
default['mconf']['user'] = 'mconf'
default['mconf']['apache-group'] = 'www-data'

# LB general configurations
default['mconf-lb']['domain'] = '192.168.0.100'
default['mconf-lb']['deploy_to'] = '/var/www/mconf-lb'

# Used for monit's "set daemon"
default['mconf-lb']['monit']['interval'] = 60 # in seconds
# Email alerts will be sent with this email as the sender
default['mconf-lb']['monit']['alert_from'] = 'support@foo'
# You can use a single email, an array of emails, or even strings with more parameters, as will be
# passed to monit's "set alert" (see https://mmonit.com/monit/documentation/monit.html).
# Examples:
#   'foo@bar'
#   'foo@bar only on { timeout, nonexist }'
#   ['baz@bar', 'foo@bar only on { timeout, nonexist }']
default['mconf-lb']['monit']['alert_to'] = 'issues@foo'

# SMTP configurations, currently used for monit only
default['mconf-lb']['smtp']['server'] = 'smtp.foo'
default['mconf-lb']['smtp']['port'] = 587
default['mconf-lb']['smtp']['username'] = 'username'
default['mconf-lb']['smtp']['password'] = 'password'
default['mconf-lb']['smtp']['timeout'] = 30
