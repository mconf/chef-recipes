#
# Cookbook Name:: mconf-monitor
# Recipe:: as_lookup
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

package "whois"

ruby_block "perform autonomous system lookup" do
  block do
    def perform_as_lookup(ip)
      whois_result = []
      begin
        process = command_execute("whois -h whois.radb.net #{ip}")
        process[:output].join().split("\n\n").each do |segment|
          entry = {}
          segment.split("\n").each do |line|
            pair = line.split(":")
            key = pair[0].strip
            value = pair[1].strip
            entry[key] = value
          end
          whois_result << entry
        end
      rescue
        Chef::Log.info("Couldn't get the AS lookup to #{ip}")
      end

      whois_result.each do |result|
        if result["source"] == "RADB"
          return result
        end
      end
      return whois_result
    end

    node.set[:mconf][:as_lookup] = perform_as_lookup(node[:bbb][:external_ip])
  end
  only_if do node[:mconf][:as_lookup].nil? end
end
