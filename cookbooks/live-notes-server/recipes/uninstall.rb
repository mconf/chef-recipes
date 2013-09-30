#
# Cookbook Name:: live-notes-server
# Recipe:: uninstall
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

service "live-notes-server" do
  provider Chef::Provider::Service::Upstart
  action [ :stop, :disable ]
  subscribes :restart, resources()
end

[ node[:notes][:xsbt][:dir],
  node[:notes][:notes_server][:dir] ].each do |dir|
    directory dir do
      recursive true
      action :delete
    end
end

[ "/usr/local/bin/sbt-launch.jar",
  "/usr/local/bin/sbt",
  "/usr/local/bin/live-notes-server",
  "/etc/init/live-notes-server.conf" ].each do |f|
    file f do
      action :delete
    end
end
