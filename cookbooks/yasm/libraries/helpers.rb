#
# Cookbook Name:: yasm
# Library:: helpers
#
# Copyright 2012-2014, Escape Studios
#

# The YASM module name-spaces all the classes of the YASM-cookbook
#
module YASM
  # Specific helpers
  #
  module Helpers
    # returns an array of package names that will install YASM on a node
    # package names returned are determined by the platform running this recipe.
    def yasm_packages
      value_for_platform(
        ['ubuntu'] => { 'default' => ['yasm'] },
        'default' => ['yasm']
      )
    end
  end
end

class Chef
  # ==Chef::Recipe
  class Recipe
    include YASM::Helpers
  end
end
