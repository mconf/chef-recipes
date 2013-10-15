#
# Cookbook Name:: mconf-monitor
# Library:: default
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

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

def process_trace_output(peer, output)
  entries = []
  # remove the first line of the output
  output.shift()
  output.each do |line|
    line.gsub!(" ms", "")

    segments = line.split(" ")
    segments.delete("*")

    entry = {
      :order => segments[0].to_i,
      :address => "UNKNOWN"
    }
    if segments.length > 1
      entry[:name] = segments[1]
      entry[:address] = segments[2][1..-2]
      begin
        entry[:as_lookup] = perform_as_lookup(entry[:address])
      rescue
        entry[:as_lookup] = nil
      end
      rtt = segments[3..-1]
      if rtt
        rtt.each_with_index do |value, idx|
          rtt[idx] = value.to_f
        end
        rtt.sort!
        entry[:rtt_min] = rtt[0]
        entry[:rtt_max] = rtt[-1]
        entry[:rtt_avg] = rtt.inject{ |sum, el| sum + el }.to_f / rtt.size
        entry[:rtt_probes] = rtt.size / 10.to_f
      end
    end

    entries << entry

    if entry[:address] == peer
      # arrived to the desired peer
      break
    end
    # it will make repeated whois less agressive
    sleep 1
  end
  entries
end

def perform_trace(ip)
  trace_result = {
    :output => nil,
    :errors => nil,
    :entries => []
  }
  process = command_execute("traceroute -I -q 10 -w 10 -m 60 #{ip}")
  trace_result[:output] = process[:output]
  trace_result[:errors] = process[:errors]
  if process[:status].success?
    trace_result[:entries] = process_trace_output(ip, process[:output])
  else
    puts "Couldn't get the trace to #{ip}: #{Array(process[:errors]).join()}"
  end
  trace_result
end

def perform_as_lookup(ip)
  whois_result = {
    :output => nil,
    :errors => nil,
    :entries => [],
    :simplified => []
  }
  process = command_execute("whois -h whois.radb.net #{ip}")
  whois_result[:output] = process[:output]
  whois_result[:errors] = process[:errors]
  if process[:status].success?
    process[:output].join().split("\n\n").each do |segment|
      entry = {}
      segment.split("\n").each do |line|
        ["route", "descr", "origin", "mnt-by", "changed", "source"].each do |identifier|
          if line.start_with? identifier
            entry[identifier] = line.slice(identifier.length + 2, line.length - (identifier.length + 2)).strip
            break
          end
        end
      end
      whois_result[:simplified] << "#{entry["origin"]} (#{entry["source"]})"
      whois_result[:entries] << entry
    end
  else
    puts "Couldn't get the AS lookup to #{ip}: #{Array(process[:errors]).join()}"
  end
  return whois_result
end
