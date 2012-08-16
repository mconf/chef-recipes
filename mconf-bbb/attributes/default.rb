default[:mconf][:bbb][:version] = "bbb0.8-mconf-0.1"
default[:mconf][:bbb][:version_int] = "1"
default[:mconf][:bbb][:file] = "#{node[:mconf][:bbb][:version]}.zip"
default[:mconf][:bbb][:repo] = "http://mconf.org:8888/mconf-node"
default[:mconf][:bbb][:url] = "#{node[:mconf][:bbb][:repo]}/#{node[:mconf][:bbb][:file]}"
default[:mconf][:bbb][:deploy_dir] = "/var/mconf/deploy/mconf-bbb"

default[:bbb][:modules] = [ "client","apps","voice","video","deskshare","demo","web","config" ]
default[:bbb][:client][:deploy_dir] = "/var/www/bigbluebutton/client"
default[:bbb][:apps][:deploy_dir] = "/usr/share/red5/webapps/bigbluebutton"
default[:bbb][:voice][:deploy_dir] = "/usr/share/red5/webapps/sip"
default[:bbb][:video][:deploy_dir] = "/usr/share/red5/webapps/video"
default[:bbb][:deskshare][:deploy_dir] = "/usr/share/red5/webapps/deskshare"
default[:bbb][:demo][:deploy_dir] = "/var/lib/tomcat6/webapps/"
default[:bbb][:web][:deploy_dir] = "/var/lib/tomcat6/webapps/"
default[:bbb][:config][:deploy_dir] = "/usr/local/bin"

