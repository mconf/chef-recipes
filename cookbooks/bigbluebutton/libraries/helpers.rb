#
# Library:: default
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

require 'digest/sha1'
require 'net/http'
require 'json'

module BigBlueButton
  # Helpers for BigBlueButton
  module Helpers
    def command_execute(command, fail_on_error = false)
      process = {}
      process[:status] = Open4::popen4(command) do | pid, stdin, stdout, stderr|
          process[:output] = stdout.readlines
          process[:errors] = stderr.readlines
      end
      if fail_on_error and not process[:status].success?
        raise "Execution failed: #{Array(process[:errors]).join()}"
      end
      process
    end

    def bigbluebutton_packages_version
      packages = [ "bbb-*", node[:bbb][:bigbluebutton][:package_name] ]
      packages_version = {}
      packages.each do |pkg|
        output = `dpkg -l | grep "#{pkg}"`
        output.split("\n").each do |entry|
          entry = entry.split()
          packages_version[entry[1]] = entry[2]
        end
      end
      packages_version
    end

    def is_running_meetings?
      begin
        params = "random=#{rand(99999)}"
        checksum = Digest::SHA1.hexdigest "getMeetings#{params}#{node[:bbb][:salt]}"
        url = URI.parse("http://localhost:8080/bigbluebutton/api/getMeetings?#{params}&checksum=#{checksum}")
        req = Net::HTTP::Get.new(url.to_s)
        res = Net::HTTP.start(url.host, url.port) { |http|
          http.request(req)
        }
        if res.body.include? "<returncode>SUCCESS</returncode>" and not res.body.include? "<messageKey>noMeetings</messageKey>"
          return true
        else
          return false
        end
      rescue
        Chef::Log.fatal("Cannot access the BigBlueButton API")
        return false
      end
    end

    def get_external_ip(server_domain)
      begin
        body = Net::HTTP.get(URI.parse("http://dig.jsondns.org/IN/#{server_domain}/A"))
        dns_query = JSON.parse(body)
        if dns_query['header']['rcode'] == 'NOERROR' and dns_query['header']['ancount'] > 0
          for answer in dns_query['answer']
            if answer['type'] == "A" and IPAddress.valid? answer['rdata']
              return answer['rdata']
            end
          end
        end

        # if couldn't be retrieved using jsondns
        # http://stackoverflow.com/questions/5742521/finding-the-ip-address-of-a-domain
        return IPSocket::getaddress(server_domain)
      rescue
        return nil
      end
    end
  end
end

Chef::Recipe.send(:include, ::BigBlueButton::Helpers)
Chef::Resource.send(:include, ::BigBlueButton::Helpers)
Chef::Provider.send(:include, ::BigBlueButton::Helpers)
