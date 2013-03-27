Description
===========

Installs/Configures reboot-handler

Allows one to reboot the server after a successfull chef run, while
in a given role.

Requirements
============

* Chef 10.12.0+

chef_handler
----

Installs/Configures chef-handler

Attributes
==========

* `default['reboot-handler']['reboot_command']` - Reboot command to execute.
* `default['reboot-handler']['enabled_role']` - Role to enable the handler on (default: booted).
* `default['reboot-handler']['post_boot_runlist']` - If set will redefine `node['run_list']` to it's value.

Usage
=====

```json
"run_list": [
    "recipe[reboot-handler]"
]
```

Simply set the following attribute while chef is executing.

    node.run_state['reboot'] = true

default
----

Installs/Configures reboot-handler

License and Author
==================

Author:: John Dewey (<john@dewey.ws>)

Copyright 2012, John Dewey

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
