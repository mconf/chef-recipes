mconf-web Cookbook
=================

Install Mconf-Web, Mconf's web portal.

Requirements
------------

Ubuntu 12.04

e.g.
#### packages
- `toaster` - mconf-web needs toaster to brown your bagel.

Attributes
----------

e.g.
#### mconf-web::default
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['mconf-web']['bacon']</tt></td>
    <td>Boolean</td>
    <td>whether to include bacon</td>
    <td><tt>true</tt></td>
  </tr>
</table>

Usage
-----
#### mconf-web::default

Just include `mconf-web` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[mconf-web]"
  ]
}
```
