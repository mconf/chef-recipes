#
# Cookbook Name:: mconf-db
# Recipe:: default
# Author:: Leonardo Crauss Daronco (<daronco@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

include_recipe 'build-essential'

execute 'apt-get update'
package 'git'

mysql_name = 'default'
mysql_service mysql_name do
  version '5.5'
  port '3306'
  bind_address '0.0.0.0'
  initial_root_password node['db']['passwords']['root']
  action [:create, :start]
end

mysql2_chef_gem 'default' do
  action :install
end

node['db']['databases'] = [node['db']['databases']] unless node['db']['databases'].is_a?(Array)
node['db']['databases'].each do |db|
  connection_info = {
    host: 'localhost',
    username: 'root',
    password: node['db']['passwords']['root'],
    socket: "/var/run/mysql-#{mysql_name}/mysqld.sock"
  }

  # create the user
  mysql_database_user db['user'] do
    connection connection_info
    password db['password']
    action :create
  end

  # create the database
  mysql_database db['name'] do
    connection connection_info
    action :create
  end

  # give the user permission on the database
  mysql_database_user db['user'] do
    connection connection_info
    database_name db['name']
    privileges [:all]
    action :grant
  end

  # give the user permission when on external hosts
  if db['hosts'] && db['hosts'].length > 0
    db['hosts'].each do |host_info|
      mysql_database_user db['user'] do
        connection connection_info
        database_name db['name']
        host host_info
        action :grant
      end
    end
  end
end
