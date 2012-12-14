#
# Cookbook Name:: bigbluebutton
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

include_recipe "ruby-1.9.2"
include_recipe "apt"

link "/usr/bin/ruby1.9.2" do
  to "/usr/local/bin/ruby"
end

%w( god builder bundler ).each do |g|
  gem_package g do
    action :install
    gem_binary('/usr/local/bin/gem')
  end
end

# `gem list` on BigBlueButton 0.8 returns the following:
#
# bundler (1.2.2)
# god (0.13.1)
# minitest (1.6.0)
# rake (0.8.7)
# rdoc (2.5.8)
{ "builder" => "2.1.2",
  "cucumber" => "0.9.2",
  "curb" => "0.7.15",
  "diff-lcs" => "1.1.2",
  "gherkin" => "2.2.9",
  "json" => "1.4.6",
  "mime-types" => "1.16",
  "nokogiri" => "1.4.4",
  "open4" => "1.3.0",
  "rack" => "1.2.2",
  "redis" => "2.1.1",
  "redis-namespace" => "0.10.0",
  "resque" => "1.15.0",
  "rspec" => "2.0.0",
  "rspec-core" => "2.0.0",
  "rspec-expectations" => "2.0.0",
  "rspec-mocks" => "2.0.0",
  "rubyzip" => "0.9.4",
  "sinatra" => "1.2.1",
  "streamio-ffmpeg" => "0.7.8",
  "term-ansicolor" => "1.0.5",
  "tilt" => "1.2.2",
  "trollop" => "1.16.2",
  "vegas" => "0.1.8" }.each do |k,v|
    gem_package "#{k}" do
        action :install
        version "#{v}"
        gem_binary('/usr/local/bin/gem')
    end
end

# add ubuntu repo
apt_repository "ubuntu" do
  uri "http://archive.ubuntu.com/ubuntu/"
  components ["lucid" , "multiverse"]
end

# create the cache directory
directory "#{Chef::Config[:file_cache_path]}" do
  recursive true
  action :create
end

# add bigbluebutton repo
apt_repository "bigbluebutton" do
  key "http://ubuntu.bigbluebutton.org/bigbluebutton.asc"
  uri "http://ubuntu.bigbluebutton.org/lucid_dev_08"
  components ["bigbluebutton-lucid" , "main"]
  # it definitely doesn't work
#  notifies :run, 'execute[apt-get update]', :immediately
end

execute "apt-get update" do
  user "root"
  action :run
end

package "bigbluebutton" do
  # we won't use the version for bigbluebutton and bbb-demo because the 
  # BigBlueButton folks don't keep the older versions
#  version node[:bbb][:version]
  response_file "bigbluebutton.seed"
  action :install
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

include_recipe "bigbluebutton::load-properties"

package "bbb-demo" do
#  version node[:bbb_demo][:version]
  if node[:bbb][:demo][:enabled]
    action :install
  else
    action :purge
  end
end

template "/usr/share/red5/webapps/deskshare/WEB-INF/red5-web.xml" do
  source "red5-web-deskshare.xml"
  mode "0644"
  variables(
    :record_deskshare => node[:bbb][:recording][:deskshare]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

template "/usr/share/red5/webapps/video/WEB-INF/red5-web.xml" do
  source "red5-web-video.xml"
  mode "0644"
  variables(
    :record_video => node[:bbb][:recording][:video]
  )
  notifies :run, "execute[restart bigbluebutton]", :delayed
end

directory "/usr/share/red5/webapps/video/streams/" do
  user "red5"
  group "red5"
  mode "0644"
  action :create
end

execute "set bigbluebutton ip" do
    user "root"
    command "bbb-conf --setip #{node[:bbb][:server_addr]}; exit 0"
    action :run
    only_if do node[:bbb][:setsalt_needed] end
end

ruby_block "reset restart flag" do
    block do
        node.set[:bbb][:force_restart] = false
    end
    only_if do node[:bbb][:force_restart] end
    notifies :run, "execute[restart bigbluebutton]", :delayed
end

execute "restart bigbluebutton" do
  user "root"
  command "bbb-conf --clean"
  action :nothing
end
