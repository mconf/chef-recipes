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

template "/var/www/bigbluebutton/client/conf/config.xml" do
  source "config.xml.erb"
  mode "0644"
  variables(
    :module_version => `xmlstarlet sel -t -v "/config/version" /var/www/bigbluebutton/client/conf/config.xml`,
    :chrome_version => `xmlstarlet sel -t -v "/config/browserVersions/@chrome" /var/www/bigbluebutton/client/conf/config.xml`,
    :firefox_version => `xmlstarlet sel -t -v "/config/browserVersions/@firefox" /var/www/bigbluebutton/client/conf/config.xml`,
    :flash_version => `xmlstarlet sel -t -v "/config/browserVersions/@flash" /var/www/bigbluebutton/client/conf/config.xml`,
    :logo => node[:mconf][:branding][:logo],
    :copyright_message => node[:mconf][:branding][:copyright_message],
    :background => node[:mconf][:branding][:background]
  )
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
