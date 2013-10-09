#
# Cookbook Name:: mconf-live
# Author:: Felipe Cecagno (<felipe@mconf.org>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

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
