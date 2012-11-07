#\TODO remove this attribute
default[:mconf][:dir] = "/var/mconf"

default[:mconf][:live][:version] = "mconf-live0.2"
default[:mconf][:live][:version_int] = "2"
default[:mconf][:live][:file] = "#{node[:mconf][:live][:version]}.tar.gz"
default[:mconf][:live][:repo] = "http://mconf.org:8888/mconf-node"
default[:mconf][:live][:url] = "#{node[:mconf][:live][:repo]}/#{node[:mconf][:live][:file]}"
default[:mconf][:live][:deploy_dir] = "#{node[:mconf][:dir]}/deploy/mconf-live"
default[:mconf][:live][:force_deploy] = "false"
