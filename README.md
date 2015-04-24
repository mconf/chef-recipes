chef-recipes
============

This repository stores contains all chef cookbooks used by Mconf. It is a collection of the cookbooks developed for Mconf plus all of their dependencies. For the latest versions of the cookbooks and to install the cookbooks in your own setup, see https://github.com/mconf-cookbooks/.

To see the version of chef being used see `.chef-version`.


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


## Running chef-solo

Install the version of chef described in `.chef-version` and then run `chef-solo` as in the
example below:


```bash
sudo chef-solo -c config/solo.rb -j utils/mconf-web.json
```
