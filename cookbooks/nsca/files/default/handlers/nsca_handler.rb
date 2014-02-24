#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This code is based on NSCAHandler from ranjibd (https://github.com/ranjibd/nsca_handler)
#

class NscaHandler < Chef::Handler
  def initialize(config={})
    @config = config
    @config[:elapsed_time_warning] ||= 30
    @config[:elapsed_time_critical] ||= 60
    @config[:updated_resources_critical] ||= 20
    @config[:updated_resources_warning] ||= 5
    @config[:send_nsca_binary] ||= '/usr/sbin/send_nsca'
    @config[:send_nsca_config] ||= '/usr/sbin/send_nsca.cfg'
    @config[:service_name] ||= 'Chef client run status'
    @config[:nsca_timeout] ||= 5
    @config
  end

  def report
    ret = run_status.failed? ? 1 : 0

    perfdata = "elapsed_time=#{run_status.elapsed_time}s;;;"
    # number of resources is useless for now
#    perfdata << " all_resources=#{run_status.all_resources.length}"
#    perfdata << " updated_resources=#{run_status.updated_resources.length}"
    output = "Elapsed time: #{run_status.elapsed_time}s"
    long_output = ""

    if run_status.failed?
      output << ", Exception: #{run_status.formatted_exception.gsub("\n", " ~~~ ")}"
      # long output is not supported on nsca 2.7.2
      long_output << "Backtrace: #{Array(run_status.backtrace).join("\n")}"
    else
      output << ", Chef Run completed successfully"
    end

    msg_string = "#{@config[:hostname]}\t#{@config[:service_name]}\t#{ret}\t#{output}|#{perfdata}\n#{long_output}".gsub('`', '\'')
    
    if @config[:nsca_server]
      @config[:nsca_server].each do |nsca_server|
        command = "echo \"#{msg_string}\" | #{@config[:send_nsca_binary]} -H #{nsca_server} -c #{@config[:send_nsca_config]} -to #{@config[:nsca_timeout]}"
        # log the command and then execute it
        Chef::Log.info("#{command}\n" + `#{command}`)
      end
    end
  end
end
