#
# Recipe:: open4
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

chef_gem "open4" do
  version "1.3.0"
  action :install
end

require 'open4'
