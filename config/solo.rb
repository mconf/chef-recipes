#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

file_cache_path "/var/chef/cache"
cookbook_path [ File.join(File.dirname(__FILE__), '../cookbooks') ]
role_path File.join(File.dirname(__FILE__), '../roles')
log_level :info

