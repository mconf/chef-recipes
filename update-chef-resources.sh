#!/bin/bash

knife cookbook upload --all --cookbook-path cookbooks/; knife role from file roles/*
