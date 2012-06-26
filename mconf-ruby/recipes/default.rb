# Cookbook Name:: mconf-ruby
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#

package "zlib1g-dev"
package "libssl-dev"
package "libreadline5-dev"
package "libyaml-dev"
package "build-essential"
package "bison"
package "checkinstall"
package "libffi5"
package "gcc"
package "checkinstall"
package "libreadline5"
package "libyaml-0-2"


#make ruby installation
script "install_tools" do
        interpreter "bash"
        user "root"
        cwd "/home/mconf"
        code <<-EOH
        cd /tmp
        wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p290.tar.gz
        tar xvzf ruby-1.9.2-p290.tar.gz
        cd ruby-1.9.2-p290
        ./configure --prefix=/usr\
                    --program-suffix=1.9.2\
                    --with-ruby-version=1.9.2\
                    --disable-install-doc
        make
        checkinstall -D -y\
                          --fstrans=no\
                          --nodoc\
                          --pkgname='ruby1.9.2'\
                          --pkgversion='1.9.2-p290'\
                          --provides='ruby'\
                          --requires='libc6,libffi5,libgdbm3,libncurses5,libreadline5,openssl,libyaml-0-2,zlib1g'\
                          --maintainer=brendan.ribera@gmail.com
        update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.2 500\
                                --slave /usr/bin/ri ri /usr/bin/ri1.9.2\
                                --slave /usr/bin/irb irb /usr/bin/irb1.9.2\
                                --slave /usr/bin/gem gem /usr/bin/gem1.9.2\
                                --slave /usr/bin/erb erb /usr/bin/erb1.9.2\
                                --slave /usr/bin/rdoc rdoc /usr/bin/rdoc1.9.2
        EOH
end



