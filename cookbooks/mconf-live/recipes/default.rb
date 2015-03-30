#
# Cookbook Name:: mconf-live
# Recipe:: default
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

if node[:mconf][:recording_server][:enabled]
  package "mconf-recording-decrypter" do
    action :upgrade
  end
  package "mconf-presentation-video" do
    ignore_failure true
    action :upgrade
  end
  package "mconf-presentation-export" do
    action :upgrade
    only_if do node[:bbb][:recording][:playback_formats].split(",").include? "presentation_export" end
  end
else
  package "mconf-recording-encrypted" do
    action :upgrade
  end
end

package "xmlstarlet"

{ "/config/branding/@logo" => node[:mconf][:branding][:logo],
    "/config/branding/@copyright" => node[:mconf][:branding][:copyright_message],
    "/config/branding/@background" => node[:mconf][:branding][:background] }.each do |key,value|
  execute ("xmlstarlet ed -L -u \"#{key}\" -v \"#{value}\" /var/www/bigbluebutton/client/conf/config.xml")
end

public_key_path = node[:mconf][:recording_server][:public_key_path]

ruby_block "save public key" do
  block do
    node.set[:keys][:recording_server_public] = File.read(public_key_path)
  end
  only_if do node[:mconf][:recording_server][:enabled] and File.exists?(public_key_path) end
end

template "/usr/local/bigbluebutton/core/scripts/mconf-decrypter.yml" do
  source "mconf-decrypter.yml.erb"
  mode 00644
  variables(
    :get_recordings_url => node[:mconf][:recording_server][:get_recordings_url],
    :private_key => node[:mconf][:recording_server][:private_key_path]
  )
  only_if do node[:mconf][:recording_server][:enabled] end
end

ruby_block "early exit" do
  block do
    raise "Early exit!"
  end
  action :nothing
end
