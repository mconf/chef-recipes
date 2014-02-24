#
# Cookbook Name:: mconf-utils
# Recipe:: chef-daemon-handler
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

execute "stop init.d chef-client daemon" do
  command "service chef-client stop"
  action :run
  returns [ 0, 1 ]
  only_if do chef_daemon_is_running() end
end

execute "stop upstart chef-client daemon" do
  command "stop chef-client"
  action :run
  returns [ 0, 1 ]
  only_if do chef_daemon_is_running() end
end

script "kill chef-client daemon" do
  interpreter "bash"
  user "root"
  code <<-EOH
    output="#{chef_daemon_process()}"
    set -- $output
    pid=$2
    kill $pid
    sleep 2
    kill -9 $pid >/dev/null 2>&1
  EOH
  only_if do chef_daemon_is_running() end
end
