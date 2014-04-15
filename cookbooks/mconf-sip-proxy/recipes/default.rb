include_recipe "freeswitch"

[ "dialplan/public.xml", "directory/default.xml" ].each do |f|
    cookbook_file "/etc/freeswitch/#{f}" do
        source f
        owner node['freeswitch']['user']
        group node['freeswitch']['group']
        mode 0644
        notifies :restart, "service[#{node['freeswitch']['service']}]", :delayed
    end
end

[ "scripts/PhoneFormat.js", "scripts/mconf_redirect.js" ].each do |f|
    cookbook_file "/usr/share/freeswitch/#{f}" do
        source f
        owner node['freeswitch']['user']
        group node['freeswitch']['group']
        mode 0644
    end
end

template "/usr/share/freeswitch/scripts/mconf_redirect_conf.js" do
    source "scripts/mconf_redirect_conf.js"
    owner node['freeswitch']['user']
    group node['freeswitch']['group']
    mode 0644
    variables fetch_url: node['freeswitch']['mconf_proxy']['fetch_url'], default_int_code: node['freeswitch']['mconf_proxy']['default_int_code']
end
