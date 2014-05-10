mconf-lb Cookbook
=================

Install Mconf-LB, Mconf's Load Balancer.

Requirements
------------

Ubuntu 12.04

e.g.
#### packages
- `toaster` - mconf-lb needs toaster to brown your bagel.

Attributes
----------

e.g.
#### mconf-lb::default
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['mconf-lb']['bacon']</tt></td>
    <td>Boolean</td>
    <td>whether to include bacon</td>
    <td><tt>true</tt></td>
  </tr>
</table>

Usage
-----
#### mconf-lb::default

Just include `mconf-lb` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[mconf-lb]"
  ]
}
```
