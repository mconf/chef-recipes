#
# Cookbook Name:: bigbluebutton
# Recipe:: abort-if-being-used
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

include_recipe "bigbluebutton::load-properties"

raise "Server being used, aborting..." if node[:bbb][:handling_meetings]
