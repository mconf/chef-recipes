#!/bin/bash

CHEF_SERVER="chef.mconf.org"

set -e

if [ ! -f /etc/chef/validation.pem ]
then
      echo "No validation key found (/etc/chef/validation.pem), aborting..."
      exit 1
fi

DEPENDENCIES_PKGS_LUCID="zlib1g-dev libssl-dev libreadline5-dev libyaml-dev build-essential bison checkinstall libffi5 gcc checkinstall libreadline5 libyaml-0-2"
DEPENDENCIES_LUCID="libc6,libffi5,libgdbm3,libncurses5,libreadline5,openssl,libyaml-0-2,zlib1g"
DEPENDENCIES_PKGS_PRECISE="zlib1g-dev libssl-dev libreadline6-dev libyaml-dev build-essential bison checkinstall libffi6 gcc checkinstall libreadline6 libyaml-0-2"
DEPENDENCIES_PRECISE="libc6,libffi6,libgdbm3,libncurses5,libreadline6,openssl,libyaml-0-2,zlib1g"

UBUNTU_VERSION=`lsb_release --codename --short`
if [ "$UBUNTU_VERSION" == "lucid" ]; then
      DEPENDENCIES_PKGS="$DEPENDENCIES_PKGS_LUCID"
      DEPENDENCIES="$DEPENDENCIES_LUCID"
elif [ "$UBUNTU_VERSION" == "precise" ]; then
        DEPENDENCIES_PKGS="$DEPENDENCIES_PKGS_PRECISE"
        DEPENDENCIES="$DEPENDENCIES_PRECISE"
else
      echo "Unsuported Ubuntu version, aborting..."
      exit 1
fi

# http://code.google.com/p/bigbluebutton/wiki/InstallationUbuntu#2._Install_Ruby
sudo apt-get update && sudo apt-get -y install $DEPENDENCIES_PKGS wget

cd /tmp
wget -N http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p290.tar.gz
tar xvzf ruby-1.9.2-p290.tar.gz
cd ruby-1.9.2-p290
./configure --prefix=/usr\
            --program-suffix=1.9.2\
            --with-ruby-version=1.9.2\
            --disable-install-doc
make
sudo checkinstall -D -y\
                  --fstrans=no\
                  --nodoc\
                  --pkgname='ruby1.9.2'\
                  --pkgversion='1.9.2-p290'\
                  --provides='ruby'\
                  --requires="$DEPENDENCIES"\
                  --maintainer=brendan.ribera@gmail.com
sudo update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.2 500 \
                         --slave /usr/bin/ri ri /usr/bin/ri1.9.2 \
                         --slave /usr/bin/irb irb /usr/bin/irb1.9.2 \
                         --slave /usr/bin/erb erb /usr/bin/erb1.9.2 \
                         --slave /usr/bin/rdoc rdoc /usr/bin/rdoc1.9.2
sudo update-alternatives --install /usr/bin/gem gem /usr/bin/gem1.9.2 500
sudo rm -r /tmp/ruby-1.9.2-p290*

cd ~/
sudo gem install chef --version '= 10.24.0' --no-ri --no-rdoc

# http://www.thelinuxdaily.com/2010/05/echo-or-cat-multiple-lines-or-paragraph-of-text-from-within-a-shell-script/
cat > client.rb << EOF
chef_server_url "http://$CHEF_SERVER:4000"
EOF
sudo mv client.rb /etc/chef/

cat > first_run.json << EOF
{
  "run_list": [ "role[mconf-server]" ]
}
EOF

sudo chef-client -j first_run.json
