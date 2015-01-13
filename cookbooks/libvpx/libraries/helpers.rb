#
# Cookbook Name:: libvpx
# Library:: helpers
#
# Copyright 2014, Escape Studios
#

# libvpx module
module Libvpx
  # helpers module
  module Helpers
    def libvpx_packages
      ['libvpx-dev', 'libvpx0']
    end
  end
end

# Chef class
class Chef
  # Recipe class
  class Recipe
    include Libvpx::Helpers
  end
end
