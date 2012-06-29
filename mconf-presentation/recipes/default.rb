# Cookbook Name:: mconf-presentation
# Recipe:: default
#
# Copyright 2012, mconf.org
#
# All rights reserved - Do Not Redistribute
#


#install presentation server
script "nagios_repo" do
        interpreter "bash"
        user "root"
        cwd "/home/mconf/"
        code <<-EOH

        cp mconf-default.pdf /var/www/bigbluebutton-default/
        sed -i 's:\(beans.presentationService.defaultUploadedPresentation\).*:\1=${bigbluebutton.web.serverURL}/mconf-default.pdf:g' /var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties
        service tomcat6 restart
        EOH
end
