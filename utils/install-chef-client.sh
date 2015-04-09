#!/bin/bash

set -xe

echo 'LANG="en_US.UTF-8"' | sudo tee /etc/default/locale
sudo apt-get update && sudo apt-get -y install locales language-pack-en
sudo update-locale LANG=en_US.UTF-8

cd
files=( ".profile" ".bashrc" )
properties=( "LC_ALL" "LANG" "LANGUAGE" )

for file in "${files[@]}"; do
    touch $file
    for property in "${properties[@]}"; do
        sed -i "/export $property=/d" $file
        echo "export $property=en_US.UTF-8" | tee -a $file
    done
done

sudo apt-get update
sudo apt-get -y install ruby1.9.3 build-essential ntp
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
VERSION=$( cat ${DIR}/../.chef-version )
sudo gem install chef --version "= ${VERSION}" --no-ri --no-rdoc
