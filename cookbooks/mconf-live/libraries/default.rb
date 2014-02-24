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
