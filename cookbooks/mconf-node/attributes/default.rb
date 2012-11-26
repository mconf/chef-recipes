#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

default[:chef_handler][:handler_path] = "/var/chef/handlers"
default[:nsca_handler][:service_name] = "Chef client run status"
# it should be a list, ex: ["server1","server2"]
default[:nsca_handler][:nsca_server] = nil
