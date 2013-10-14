#
# Cookbook Name:: mconf-monitor
# Recipe:: traceroute
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

chef_gem "open4" do
  version "1.3.0"
  action :install
end

require 'open4'

package "traceroute"
package "whois"

ruby_block "collect topology" do
  block do
    if node[:mconf][:remount_topology]
      node.set[:mconf][:topology] = {}
      node.set[:mconf][:as_lookup] = nil
      node.set[:mconf][:remount_topology] = false
    end

    if node[:mconf][:as_lookup].nil?
      begin
        node.set[:mconf][:as_lookup] = perform_as_lookup(node[:bbb][:internal_ip])
      rescue
        
      end
    end

    source_entry = {
      :order => 0,
      :name => node[:bbb][:server_domain],
      :address => node[:bbb][:internal_ip],
      :as_lookup => node[:mconf][:as_lookup].to_hash
    }

    list_of_peers = []
    list_of_peers = search(:node, "role:mconf-node AND chef_environment:#{node.chef_environment}") unless Chef::Config[:solo]
    list_of_peers.each do |peer|
      if peer[:bbb][:external_ip] != node[:bbb][:external_ip] and
          (not node[:mconf][:topology].has_key?("#{peer[:fqdn]}") or node[:mconf][:topology]["#{peer[:fqdn]}"][:entries].last[:address] == "UNKNOWN")

        trace_result = perform_trace(peer[:bbb][:external_ip])

        trace_result[:entries] << source_entry
        trace_result[:entries].sort_by! { |a| a[:order] }

        node.set[:mconf][:topology]["#{peer[:fqdn]}"] = trace_result
        # Chef::Log.info("Topology from #{node[:fqdn]} to #{peer[:fqdn]}:\n#{trace_result}")

        # it will make repeated traces less agressive
        sleep 5
      end
    end
  end
  only_if do (node[:roles].length > 0 and node[:roles][0] == "mconf-node") or Chef::Config[:solo] end
end
