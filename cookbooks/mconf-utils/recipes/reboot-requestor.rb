#
# Cookbook Name:: mconf-utils
# Recipe:: reboot-handler
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

package "update-notifier-common"

if tagged?("reboot") # or File.exists? "/var/run/reboot-required"
  node.run_state['reboot'] = true
  untag("reboot")
end
