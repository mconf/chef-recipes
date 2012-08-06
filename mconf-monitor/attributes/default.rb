default[:mconf][:nagios_address] = "localhost"
default[:mconf][:instance_type] = "bigbluebutton"
default[:mconf][:interval] = "10"
default[:mconf][:nagios][:dir] = "/var/mconf/tools/nagios"
# space separated values
default[:mconf][:monitoring_servers] = "lb.mconf.org lb1.mconf.org"

default[:nsca][:version] = "2.7.2"
default[:nsca][:dir] = "/usr/local/nagios/bin"
default[:nsca][:config_dir] = "/usr/local/nagios/etc"

