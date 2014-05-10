#
# Cookbook Name:: mconf-lb
# Recipe:: default
# Author:: Leonardo Crauss Daronco (<daronco@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

execute "apt-get update"

node.set["build_essential"]["compiletime"] = false
include_recipe "build-essential"

package "libssl-dev"
package "libgeoip-dev"
package "libexpat1-dev"

# Install MySQL Server
mysql_service "default" do
  version "5.5"
  port "3306"
  server_root_password node["db"]["passwords"]["root"]
  server_repl_password node["db"]["passwords"]["repl"]
  action :create
end
# template "/etc/mysql/conf.d/mysite.cnf" do
#   owner "mysql"
#   owner "mysql"
#   source "mysite.cnf.erb"
#   notifies :restart, "mysql_service[default]"
# end

# Node.js
node.set["nodejs"]["install_method"] = "source"
node.set["nodejs"]["version"] = "0.8.25"
node.set["nodejs"]["npm"] = "1.3.7"
include_recipe "nodejs"
include_recipe "nodejs::npm"

# Configure a user and a database for our app
include_recipe "database::mysql"
connection_info = {
  :host     => "localhost",
  :username => "root",
  :password => node["db"]["passwords"]["root"]
}
mysql_database_user node["db"]["user"] do
  connection connection_info
  password   node["db"]["passwords"]["app"]
  action     :create
end
mysql_database node["db"]["name"] do
  connection connection_info
  action :create
end
mysql_database_user node["db"]["user"] do
  connection    connection_info
  database_name node["db"]["name"]
  privileges    [:all]
  action        :grant
end

# Nginx installation

# Install from source because we need a newer version
nginx_version = "1.6.0"
node.set["nginx"]["version"] = nginx_version
node.set["nginx"]["install_method"] = "source"
node.set["nginx"]["init_style"] = "init"
node.set["nginx"]["default_site_enabled"] = false
# Something in nginx's recipe makes it use the default version instead of the one we set here, so we
# have to override a few attributes.
# More at: http://stackoverflow.com/questions/17679898/how-to-update-nginx-via-chef
node.set["nginx"]["source"]["version"] = nginx_version
node.set["nginx"]["source"]["url"] = "http://nginx.org/download/nginx-#{nginx_version}.tar.gz"
node.set["nginx"]["source"]["prefix"] = "/opt/nginx-#{nginx_version}"
node.set['nginx']['source']['default_configure_flags'] = %W(
  --prefix=#{node['nginx']['source']['prefix']}
  --conf-path=#{node['nginx']['dir']}/nginx.conf
  --sbin-path=#{node['nginx']['source']['sbin_path']}
)
include_recipe "nginx"

## alternative: install from a PPA
# node.set["nginx"]["version"] = "1.6.0"
# node.set["nginx"]["install_method"] = "package"
# apt_repository "nginx" do
#   uri "http://ppa.launchpad.net/nginx/stable/ubuntu"
#   components ["precise", "main"]
#   keyserver "keyserver.ubuntu.com"
#   key "C300EE8C"
# end
# execute "apt-get update"
# include_recipe "nginx"

# Nginx configurations
directory "/etc/nginx/includes" do
  owner "root"
  group "root"
  mode 00755
  action :create
end
template "/etc/nginx/includes/mconf-lb-proxy.conf" do
  source "nginx-include.erb"
  mode 00644
  owner "root"
  group "root"
end
template "/etc/nginx/sites-available/mconf-lb" do
  source "nginx-site.erb"
  mode 00644
  owner "root"
  group "root"
  variables({
    :domain => node["mconf-lb"]["domain"]
  })
end
execute "nxensite mconf-lb"
service "nginx" do
  action :restart
end

# Upstart
template "/etc/init/mconf-lb.conf" do
  source "upstart-script.erb"
  mode 00644
  owner "root"
  group "root"
end

# Monit
# TODO: can we set an specific version?
package "monit"
template "/etc/monit/conf.d/mconf-lb" do
  source "monit-config.erb"
  mode 00644
  owner "root"
  group "root"
end
template "/etc/monit/monitrc" do
  source "monitrc.erb"
  mode 00600
  owner "root"
  group "root"
end
service "monit" do
  action :restart
end

# logrotate
template "/etc/logrotate.d/mconf-lb" do
  source "logrotate-config.erb"
  mode 00644
  owner "root"
  group "root"
end
execute "logrotate -s /var/lib/logrotate/status /etc/logrotate.d/mconf-lb"
