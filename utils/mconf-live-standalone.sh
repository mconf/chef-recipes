#!/bin/bash

set -xe

sudo chef-solo -c ~/chef-recipes/config/solo.rb -j mconf-live-standalone.json
