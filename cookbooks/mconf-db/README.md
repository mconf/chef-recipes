mconf-db Cookbook
=================

Install the database used by some components of Mconf.

Requirements
------------

Ubuntu 14.04

e.g.
#### packages
- `toaster` - mconf-db needs toaster to brown your bagel.

Attributes
----------

e.g.
#### mconf-db::default
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['mconf-db']['bacon']</tt></td>
    <td>Boolean</td>
    <td>whether to include bacon</td>
    <td><tt>true</tt></td>
  </tr>
</table>

Usage
-----
#### mconf-db::default

Just include `mconf-db` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[mconf-db]"
  ]
}
```
