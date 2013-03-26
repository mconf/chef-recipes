#!/bin/bash

knife cookbook upload --all --cookbook-path cookbooks/
for i in `ls data_bags/`; do
	knife data bag delete -y $i
	knife data bag create $i
	knife data bag from file $i data_bags/$i/*
done
knife role from file roles/*
knife environment from file environments/*.rb
