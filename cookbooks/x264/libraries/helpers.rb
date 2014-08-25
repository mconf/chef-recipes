#
# Cookbook Name:: x264
# Library:: helpers
#
# Copyright 2014, Escape Studios
#

# X264 module
module X264
  # helpers module
  module Helpers
    def x264_packages
      [
        'libx264-85',
        'libx264-dev'
      ]
    end
  end
end

# Chef class
class Chef
  # Recipe class
  class Recipe
    include X264::Helpers
  end
end
