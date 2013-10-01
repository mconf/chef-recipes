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

package "traceroute"

chef_gem "open4" do
  version "1.3.0"
  action :install
end

require 'open4'

ruby_block "collect topology" do
  block do
    # \TODO this code is almost duplicated from mconf-live::default
    def execute(command)
        process = {}
        process[:status] = Open4::popen4(command) do | pid, stdin, stdout, stderr|
            Chef::Log.info("Executing: #{command}")

            process[:output] = stdout.readlines
            Chef::Log.info("stdout: #{Array(process[:output]).join()} ") unless process[:output].empty?

            process[:errors] = stderr.readlines
            Chef::Log.error("stderr: #{Array(process[:errors]).join()}") unless process[:errors].empty?
        end
        if not process[:status].success?
            raise "Execution failed, raising an exception"
        end
        process
    end

    def process_trace_output(output)
      entry = []
      output.each do |line|
        line.gsub!(" ms", "")
        segments = line.split(" ")
        # the line is valid, we could extract all information
        # ex: " 1  10.0.3.1  0.087 ms  0.029 ms  0.023 ms"
        answered = (segments.length == 5)
        # the line is still valid but the router didn't answer
        # ex: " 5  * * *"
        not_answered = (segments.length == 4)

        if answered
          entry << {
            :order => segments[0].to_i,
            :peer => segments[1],
            :rtt_min => segments[2],
            :rtt_avg => segments[3],
            :rtt_max => segments[4]
          }
        elsif not_answered
          entry << {
            :order => segments[0],
            :peer => "UNKNOWN"
          }
        end
      end
      entry
    end

    def perform_trace(peer)
      trace_result = nil
      begin
        process = execute("traceroute -I -n #{peer}")
        trace_result = process_trace_output(process[:output])
      rescue
        Chef::Log.info("Couldn't get the trace to #{peer}")
      end
      trace_result
    end

    # TEMPORARY CODE
    # it will force the topology to be remounted on every run
    node.set[:mconf][:topology] = {}

    list_of_peers = []
    list_of_peers = search(:node, "role:mconf-node AND chef_environment:#{node.chef_environment}") unless Chef::Config[:solo]
    list_of_peers.each do |peer|
      if peer[:ipaddress] != node[:ipaddress] and not node[:mconf][:topology].has_key? "#{peer[:fqdn]}"
        trace_result = perform_trace(peer[:ipaddress])

        trace_result << {
          :order => 0,
          :peer => node[:ipaddress]
        }
        trace_result.sort! {|a,b| a[:order] <=> b[:order] }

        node.set[:mconf][:topology]["#{peer[:fqdn]}"] = trace_result
      end
    end
  end
  only_if do node[:roles].length > 0 and node[:roles][0] == "mconf-node" end
end