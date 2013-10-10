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

# \TODO extract this code to a library
chef_gem "open4" do
  version "1.3.0"
  action :install
end

require 'open4'

def command_execute(command, fail_on_error = false)
  process = {}
  process[:status] = Open4::popen4(command) do | pid, stdin, stdout, stderr|
      Chef::Log.info("Executing: #{command}")

      process[:output] = stdout.readlines
      Chef::Log.info("stdout: #{Array(process[:output]).join()} ") unless process[:output].empty?

      process[:errors] = stderr.readlines
      Chef::Log.error("stderr: #{Array(process[:errors]).join()}") unless process[:errors].empty?
  end
  if fail_on_error and not process[:status].success?
    raise "Execution failed: #{Array(process[:errors]).join()}"
  end
  process
end

package "traceroute"

ruby_block "collect topology" do
  block do
    def process_trace_output(peer, output)
      entry = []
      output.each do |line|
        line.gsub!(" ms", "")
        segments = line.split(" ")
        ignore_input = (segments.length < 4 or segments.length > 5)

        if ignore_input
          next
        end

        order = segments[0].to_i

        if segments[1, 3].join(' ') == "* * *"
          # ex: " 5  * * *"
          entry << {
            :order => order,
            :peer => "UNKNOWN"
          }
        elsif segments[1, 2].join(' ') == "* *"
          #ex: " 1  * * 200.130.35.1  13.567 ms"
          entry << {
            :order => order,
            :peer => segments[3],
            :rtt_max => segments[4]
          }
        elsif segments[1] == "*"
          #ex: " 1  * 200.130.35.1  10 ms  13.567 ms"
          entry << {
            :order => order,
            :peer => segments[2],
            :rtt_avg => segments[3],
            :rtt_max => segments[4]
          }
        else
          # ex: " 1  10.0.3.1  0.087 ms  0.029 ms  0.023 ms"
          entry << {
            :order => order,
            :peer => segments[1],
            :rtt_min => segments[2],
            :rtt_avg => segments[3],
            :rtt_max => segments[4]
          }
        end
        if entry.last[:peer] == peer
          # arrived to the desired peer
          break
        end
      end
      entry
    end

    def perform_trace(ip)
      trace_result = []
      begin
        process = command_execute("traceroute -I -n #{ip}")
        trace_result = process_trace_output(ip, process[:output])
      rescue
        Chef::Log.info("Couldn't get the trace to #{ip}")
      end
      trace_result
    end

    if node[:mconf][:remount_topology]
      node.set[:mconf][:topology] = {}
      node.set[:mconf][:remount_topology] = false
    end

    list_of_peers = []
    list_of_peers = search(:node, "role:mconf-node AND chef_environment:#{node.chef_environment}") unless Chef::Config[:solo]
    list_of_peers.each do |peer|
      if peer[:bbb][:external_ip] != node[:bbb][:external_ip] and
          (not node[:mconf][:topology].has_key?("#{peer[:fqdn]}") or node[:mconf][:topology]["#{peer[:fqdn]}"].last[:peer] == "UNKNOWN")

        trace_result = perform_trace(peer[:bbb][:external_ip])

        trace_result << {
          :order => 0,
          :peer => node[:ipaddress]
        }
        trace_result.sort_by! { |a| a[:order] }

        node.set[:mconf][:topology]["#{peer[:fqdn]}"] = trace_result
        # Chef::Log.info("Topology from #{node[:fqdn]} to #{peer[:fqdn]}:\n#{trace_result}")

        # it will make repeated traces less agressive
        sleep 5
      end
    end
  end
  only_if do (node[:roles].length > 0 and node[:roles][0] == "mconf-node") or Chef::Config[:solo] end
end
