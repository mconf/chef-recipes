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

cookbook_file "/usr/share/freeswitch/scripts/PhoneFormat.js" do
    source "scripts/PhoneFormat.js"
    owner node['freeswitch']['user']
    group node['freeswitch']['group']
    mode 0644
end

template "/usr/share/freeswitch/scripts/mconf_redirect.js" do
    source "scripts/mconf_redirect.js"
    owner node['freeswitch']['user']
    group node['freeswitch']['group']
    mode 0644
    variables fetch_url: node['freeswitch']['mconf_proxy']['fetch_url'], default_int_code: node['freeswitch']['mconf_proxy']['default_int_code']
end
