maintainer       "John Dewey"
maintainer_email "john@dewey.ws"
license          "Apache 2.0"
description      "Installs/Configures reboot-handler"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.2.0"

recipe           "reboot-handler", "Installs/Configures reboot-handler"

%w{ debian ubuntu }.each do |os|
  supports os
end

depends "chef_handler"
