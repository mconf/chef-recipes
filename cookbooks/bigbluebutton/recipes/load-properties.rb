#
# Cookbook Name:: bigbluebutton
# Recipe:: load-properties
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

require 'socket'
require 'securerandom'
require 'ipaddress'

ruby_block "print warning" do
    block do
        Chef::Log.info("This is being printed on execution phase")
    end
    action :create
end

define_properties = ruby_block "define bigbluebutton properties" do
    block do
        if File.exists?('/var/lib/tomcat7/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties')
            properties = Hash[File.read('/var/lib/tomcat7/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties').scan(/(.+?)=(.+)/)]

            # node[:bbb][:server_url] = "http://<SERVER_IP>:<SERVER_PORT>"
            if not node[:bbb][:ip].nil? and not node[:bbb][:ip].empty?
                if not node[:bbb][:ip].start_with?("http://")
                    node.set[:bbb][:ip] = "http://#{node[:bbb][:ip]}"
                end
                node.set[:bbb][:server_url] = node[:bbb][:ip]
            else
                node.set[:bbb][:server_url] = "http://#{node[:ipaddress]}"
            end
            
            # node[:bbb][:server_addr] = "<SERVER_IP>:<SERVER_PORT>"
            node.set[:bbb][:server_addr] = node[:bbb][:server_url].gsub("http://", "")
            # node[:bbb][:server_domain] = "<SERVER_IP>"
            node.set[:bbb][:server_domain] = node[:bbb][:server_addr].split(":")[0]
            node.set[:bbb][:internal_ip] = node[:ipaddress]

            external_ip = get_external_ip(node[:bbb][:server_domain])
            if external_ip.nil? or external_ip.empty?
                external_ip = node[:bbb][:internal_ip]
            end
            node.set[:bbb][:external_ip] = external_ip

            if not node[:bbb][:enforce_salt].nil? and not node[:bbb][:enforce_salt].empty?
                node.set[:bbb][:salt] = node[:bbb][:enforce_salt]
            else
                node.set[:bbb][:salt] = properties["securitySalt"]
            end
            
            # this is just an extra check in case that the salt doesn't get saved properly on the node
            if node[:bbb][:salt].nil? or node[:bbb][:salt].empty?
                # http://stackoverflow.com/questions/88311/how-best-to-generate-a-random-string-in-ruby
                node.set[:bbb][:salt] = SecureRandom.hex(16)
            end
            node.set[:bbb][:setsalt_needed] = (node[:bbb][:salt] != properties["securitySalt"])
            node.set[:bbb][:setip_needed] = (node[:bbb][:server_url] != properties["bigbluebutton.web.serverURL"])
            node.save unless Chef::Config[:solo]

            node.set[:bbb][:handling_meetings] = is_running_meetings?

            Chef::Log.info("\tserver_url       : #{node[:bbb][:server_url]}")
            Chef::Log.info("\tserver_addr      : #{node[:bbb][:server_addr]}")
            Chef::Log.info("\tserver_domain    : #{node[:bbb][:server_domain]}")
            Chef::Log.info("\tinternal_ip      : #{node[:bbb][:internal_ip]}")
            Chef::Log.info("\texternal_ip      : #{node[:bbb][:external_ip]}")
            Chef::Log.info("\tsalt             : #{node[:bbb][:salt]}")
            Chef::Log.info("\t--setip needed?    #{node[:bbb][:setip_needed]}")
            Chef::Log.info("\thandling_meetings: #{node[:bbb][:handling_meetings]}")
        end
    end
    action :create
end

# it will make this block to execute before the others
if File.exists?('/var/lib/tomcat7/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties')
    Chef::Log.info("This is being printed on compile phase")
    define_properties.run_action(:create)
end

