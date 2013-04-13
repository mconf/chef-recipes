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
require 'digest/sha1'
require 'net/http'
require 'json'

ruby_block "print warning" do
    block do
        Chef::Log.info("This is being printed on execution phase")
    end
    action :create
end

define_properties = ruby_block "define bigbluebutton properties" do
    block do
        if File.exists?('/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties')
            properties = Hash[File.read('/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties').scan(/(.+?)=(.+)/)]

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

            begin
                body = Net::HTTP.get(URI.parse("http://dig.jsondns.org/IN/#{node[:bbb][:server_domain]}/A"))
                dns_query = JSON.parse(body)
                if dns_query['header']['rcode'] == 'NOERROR' and dns_query['header']['ancount'] > 0
                    node.set[:bbb][:external_ip] = dns_query['answer'][0]['rdata']
                else
                    # http://stackoverflow.com/questions/5742521/finding-the-ip-address-of-a-domain
                    node.set[:bbb][:external_ip] = IPSocket::getaddress(node[:bbb][:server_domain])
                end
            rescue
            end
            node.set[:bbb][:internal_ip] = node[:ipaddress]

            if not node[:bbb][:enforce_salt].nil? and not node[:bbb][:enforce_salt].empty?
                node.set[:bbb][:salt] = node[:bbb][:enforce_salt]
            else
                node.set[:bbb][:salt] = properties["securitySalt"]
            end
            
            if node[:bbb][:salt].nil? or node[:bbb][:salt].empty?
                # http://stackoverflow.com/questions/88311/how-best-to-generate-a-random-string-in-ruby
                node.set[:bbb][:salt] = SecureRandom.hex(16)
            end
            node.set[:bbb][:setsalt_needed] = (node[:bbb][:salt] != properties["securitySalt"])
            node.set[:bbb][:setip_needed] = (node[:bbb][:server_url] != properties["bigbluebutton.web.serverURL"])
            node.save unless Chef::Config[:solo]
            
            begin
                params = "random=#{rand(99999)}"
                checksum = Digest::SHA1.hexdigest "getMeetings#{params}#{node[:bbb][:salt]}"
                url = URI.parse("http://localhost:8080/bigbluebutton/api/getMeetings?#{params}&checksum=#{checksum}")
                req = Net::HTTP::Get.new(url.to_s)
                res = Net::HTTP.start(url.host, url.port) { |http|
                  http.request(req)
                }
                if res.body.include? "<returncode>SUCCESS</returncode>" and not res.body.include? "<messageKey>noMeetings</messageKey>"
                  # \TODO create another way to abort the chef run without call the exception 
                  # handler or handling this particular exception into the exception handler 
                  # to not send the nsca message
                  #raise "Can't continue because there are meetings currently running"
                  #exit 0
                  #Chef::Application.fatal!("Can't continue because there are meetings currently running", 0)
                  node.set[:bbb][:handling_meetings] = true
                else
                  node.set[:bbb][:handling_meetings] = false
                end
            rescue
                Chef::Log.fatal("Cannot access the BigBlueButton API")
                node.set[:bbb][:handling_meetings] = false
            end

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
if File.exists?('/var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties')
    Chef::Log.info("This is being printed on compile phase")
    define_properties.run_action(:create)
end

