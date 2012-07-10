chef-recipes
============

Storage of chef recipes for the Mconf plataform.

To run the recipes in a development environment, set solo.rb according to your environment. Then execute:

sudo shef --solo --config solo.rb -j runlist.json

On shef, execute:

chef > recipe
chef:recipe > load_recipe "<cookbook>::<recipe>"
chef:recipe > run_chef

If you want to reload your recipe after a change, execute:

chef:recipe > run_context.resource_collection = Chef::ResourceCollection.new

Then load your recipe again and run it normally.
