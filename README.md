chef-recipes
============

To install the Mconf SIP Proxy, install Ruby and chef-client, then run:

```
sudo chef-solo -c ~/chef-recipes/config/solo.rb -j ~/chef-recipes/utils/mconf-sip-proxy.json
```

This repo stores chef cookbooks for the Mconf plataform.

These recipes are developed and tested using the chef gem version 10.24.0.

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
