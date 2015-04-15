#
# Cookbook Name:: mconf-web
# Recipe:: default
# Author:: Leonardo Crauss Daronco (<daronco@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

execute 'apt-get update'

include_recipe 'build-essential'

package 'git'
package 'libruby'
package 'aspell-en'
package 'libxml2-dev'
package 'libxslt1-dev'
package 'libmagickcore-dev'
package 'libmagickwand-dev'
package 'imagemagick'
package 'zlib1g-dev'
package 'libreadline-dev'
package 'libffi-dev'
package 'nfs-common'
package 'libcurl4-openssl-dev'
package 'openjdk-7-jre'
package 'redis-server'


# Database (MySQL) + user

mysql_service 'default' do
  version '5.5'
  port '3306'
  server_root_password node['mconf-web']['db']['passwords']['root']
  server_repl_password node['mconf-web']['db']['passwords']['repl']
  action :create
end

include_recipe 'database::mysql'

connection_info = {
  :host     => 'localhost',
  :username => 'root',
  :password => node['mconf-web']['db']['passwords']['root']
}

mysql_database_user node['mconf-web']['db']['user'] do
  connection connection_info
  password   node['mconf-web']['db']['passwords']['app']
  action     :create
end

mysql_database node['mconf-web']['db']['name'] do
  connection connection_info
  action :create
end

mysql_database_user node['mconf-web']['db']['user'] do
  connection    connection_info
  database_name node['mconf-web']['db']['name']
  privileges    [:all]
  action        :grant
end


# Ruby
include_recipe 'ruby_build'
include_recipe 'rbenv::system'


# Apache2 + Passenger
# Note: as of 2015.04.10, the cookbook passenger_apache2 still didn't support apache 2.4,
# so we can't use it in ubuntu 14.04 yet.
# The block below is mostly taken from that cookbook.

%W(apache2-prefork-dev libapr1-dev libcurl4-gnutls-dev apache2-mpm-worker ruby-dev).each do |pkg|
  package pkg do
    action :upgrade
  end
end

gem_package 'passenger' do
  version node['passenger']['version']
end

execute 'passenger_module' do
  command "#{node['passenger']['ruby_bin']} #{node['passenger']['root_path']}/bin/passenger-install-apache2-module _#{node['passenger']['version']}_ --auto"
  only_if { node['passenger']['install_module'] }
  # this is late eval'd when Chef converges this resource, and the
  # attribute may have been modified by the `mod_rails` recipe.
  not_if { ::File.exist?(node['passenger']['module_path']) }
end

include_recipe 'apache2'

apache_module 'rewrite'

apache_site "default" do
  enable false
end

web_app 'mconf-web' do
  template 'apache-site.conf.erb'
  docroot node['mconf-web']['deploy_to']
  server_name node['mconf-web']['domain']
end


# Monit

package "monit"
service "monit"

template "/etc/monit/conf.d/mconf-web" do
  source "monit-config.erb"
  mode 00644
  owner "root"
  group "root"
  notifies :restart, "service[monit]", :delayed
end

template "/etc/monit/monitrc" do
  source "monitrc.erb"
  mode 00600
  owner "root"
  group "root"
  notifies :restart, "service[monit]", :delayed
end


# Logrotate

logrotate_app 'mconf-web' do
  cookbook 'logrotate'
  path [ "#{node['mconf-web']['deploy_to']}/log/production.log", "#{node['mconf-web']['deploy_to']}/log/resque_*.log" ]
  options [ 'missingok', 'compress', 'copytruncate', 'notifempty' ]
  frequency 'daily'
  rotate 10
  size '50M'
  create '644 mconf www-data'
end

# Create the app directory
# (Just the directory, capistrano does the rest)

directory node['mconf-web']['deploy_to'] do
  owner node['mconf']['user']
  group node['mconf']['apache-group']
  mode '0755'
  action :create
end
