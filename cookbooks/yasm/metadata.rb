maintainer       "Escape Studios"
maintainer_email "dev@escapestudios.com"
license          "MIT"
description      "Installs/Configures yasm"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.0.2"

%w{ debian ubuntu centos redhat fedora scientific amazon }.each do |os|
supports os
end

depends "build-essential"
depends "git"