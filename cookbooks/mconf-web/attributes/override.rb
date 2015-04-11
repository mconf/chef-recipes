#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

override["build_essential"]["compiletime"] = false

ruby_version = '2.2.0'
override['rbenv']['rubies'] = [ruby_version]
override['rbenv']['global'] = ruby_version
override['rbenv']['gems'] = {
  ruby_version => [
    { name: 'bundler',
      version: '1.7.2'
    }
  ]
}

override['passenger']['version']     = '4.0.59'
override['passenger']['apache_mpm']  = nil
override['passenger']['root_path']   = "#{languages['ruby']['gems_dir']}/gems/passenger-#{passenger['version']}"
override['passenger']['module_path'] = "#{passenger['root_path']}/buildout/apache2/mod_passenger.so"
override['passenger']['max_pool_size'] = 6
override['passenger']['manage_module_conf'] = true
override['passenger']['package']['name'] = nil
# set package version to nil, the distro package may not be the same version
override['passenger']['package']['version'] = nil
override['passenger']['ruby_bin'] = languages['ruby']['ruby_bin']
override['passenger']['install_module'] = true

# # Install from source because we need a newer version
# nginx_version = "1.6.0"
# override["nginx"]["version"] = nginx_version
# override["nginx"]["install_method"] = "source"
# override["nginx"]["init_style"] = "init"
# override["nginx"]["default_site_enabled"] = false
# # Something in nginx's recipe makes it use the default version instead of the one we set here, so we
# # have to override a few attributes.
# # More at: http://stackoverflow.com/questions/17679898/how-to-update-nginx-via-chef
# override["nginx"]["source"]["version"] = nginx_version
# override["nginx"]["source"]["url"] = "http://nginx.org/download/nginx-#{nginx_version}.tar.gz"
# override["nginx"]["source"]["prefix"] = "/opt/nginx-#{nginx_version}"
# override['nginx']['source']['default_configure_flags'] = %W(
#   --prefix=#{node['nginx']['source']['prefix']}
#   --conf-path=#{node['nginx']['dir']}/nginx.conf
#   --sbin-path=#{node['nginx']['source']['sbin_path']}
# )
