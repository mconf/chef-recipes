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

package("zlib1g-dev").run_action(:install)
[ "nokogiri", "htmlentities" ].each do |g|
  chef_gem g do
    action :install
  end
  
  require g
end

config_xml = "/var/www/bigbluebutton/client/conf/config.xml"
module_version = ""
chrome_version = ""
firefox_version = ""
flash_version = ""
default_layout = ""

# the information here will always contain the original repository values
ruby_block "parse config.xml information" do
  block do
    doc = Nokogiri::XML(open(config_xml).read)
    module_version = doc.xpath("/config/version").first.content
    chrome_version = doc.xpath("/config/browserVersions/@chrome").first.value
    firefox_version = doc.xpath("/config/browserVersions/@firefox").first.value
    flash_version = doc.xpath("/config/browserVersions/@flash").first.value
    default_layout = doc.xpath("/config/layout/@defaultLayout").first.value
    Chef::Log.info "module_version: #{module_version}"
    Chef::Log.info "chrome_version: #{chrome_version}"
    Chef::Log.info "firefox_version: #{firefox_version}"
    Chef::Log.info "flash_version: #{flash_version}"
    Chef::Log.info "default_layout: #{default_layout}"
  end
end

template config_xml do
  def as_html(s)
    return HTMLEntities.new.encode(s, :basic, :decimal)
  end
  
  source "config.xml.erb"
  mode "0644"
  variables(
    lazy {{
      :module_version => module_version,
      :chrome_version => chrome_version,
      :firefox_version => firefox_version,
      :flash_version => flash_version,
      :default_layout => default_layout,
      :logo => as_html(node[:mconf][:branding][:logo]),
      :copyright_message => as_html(node[:mconf][:branding][:copyright_message]),
      :background => as_html(node[:mconf][:branding][:background]),
      :server_domain => node[:bbb][:server_domain],
      :server_url => node[:bbb][:server_url]
    }}
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
