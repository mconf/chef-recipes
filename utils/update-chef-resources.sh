#!/bin/bash

set -xe

knife cookbook upload --all --cookbook-path ../cookbooks/
for i in `ls ../data_bags/`; do
	set +e
	knife data bag delete -y $i
	set -e
	knife data bag create $i
	find ../data_bags/$i/ -type f \( -iname "*.rb" -o -iname "*.json" \) -exec knife data bag from file $i {} \; 
done
find ../roles/ -type f \( -iname "*.rb" -o -iname "*.json" \) -exec knife role from file {} \;
find ../environments/ -type f \( -iname "*.rb" -o -iname "*.json" \) -exec knife environment from file {} \;

