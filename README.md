chef-recipes
============

This repo stores chef cookbooks for the Mconf plataform.

These recipes are developed and tested using the chef gem version 10.24.0.


#### Cookbooks

To install cookbooks from the Opscode Community:

```
knife cookbook site install COOKBOOK_NAME --cookbook-path cookbooks/ --use-current-branch
```

To install cookbooks from arbitrary GitHub repositories, first you need the gem knife-github-cookbooks:

```
sudo gem install knife-github-cookbooks
```

Then execute:

```
knife cookbook github install Youscribe/hostname-cookbook --cookbook-path cookbooks/ --use-current-branch
```

The above command will install the cookbook from https://github.com/Youscribe/hostname-cookbook.

#### Mconf SIP Proxy

To install the Mconf SIP Proxy, install Ruby and chef-client, then run:

```
sudo chef-solo -c ~/chef-recipes/config/solo.rb -j ~/chef-recipes/utils/mconf-sip-proxy.json
```

#### Mconf LB

To install the load balancer, first edit `chef-recipes/utils/mconf-lb.json` to set the variables for
the instance you're installing.

Then install Ruby and chef-client, then run:

```
sudo chef-solo -c ~/chef-recipes/config/solo.rb -j ~/chef-recipes/utils/mconf-lb.json
```

## Working with librarian

Install it:

```bash
bundle install
```

To add a cookbook, first add it to `Cheffile` and then (note: it's always usefull to use `--verbose` with librarian):

```bash
bundle exec librarian-chef install [--verbose]
```

Update a cookbook:

```bash
bundle exec librarian-chef update mconf-lb [--verbose]
```

## Vagrant

Install Vagrant.

Install plugins for Vagrant:

```bash
vagrant plugin install vagrant-lxc
vagrant plugin install vagrant-vbguest
vagrant plugin install vagrant-librarian-chef
vagrant plugin install vagrant-omnibus
```

Download the dependencies:

```bash
bundle install
rbenv rehash

cd vagrant/
bundle exec librarian-chef install [--verbose]
```

Create the VM:

```bash
cd ../
vagrant up
```

Log into the VM

```bash
vagrant ssh
cd vagrant/
bundle install
```

Now you can run chef-solo as in:

```bash
sudo chef-solo -c /vagrant/config/solo.rb -j utils/mconf-web.json
```
