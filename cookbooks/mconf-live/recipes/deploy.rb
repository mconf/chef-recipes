#
# Cookbook Name:: mconf-live
# Recipe:: deploy
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

# http://chrisa.github.com/blog/2012/07/05/custom-chef-gem-resources/

chef_gem "open4" do
  version "1.3.0"
  action :install
end

require 'open4'

execute "bbb-conf --stop" do
  user "root"
  action :run
  only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

node.set[:mconf][:live][:url] = "#{node[:mconf][:live][:repo]}/#{node[:mconf][:live][:file]}"

if node[:mconf][:live][:repo].start_with? "http://"
  remote_file "#{Chef::Config[:file_cache_path]}/#{node[:mconf][:live][:file]}" do
    source node[:mconf][:live][:url]
    mode "0644"
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
  end
else
  # this is a workaround to be able to install Mconf-Live from a local file instead of a remote one
  FileUtils.cp node[:mconf][:live][:url], "#{Chef::Config[:file_cache_path]}/#{node[:mconf][:live][:file]}"
end

execute "untar mconf-live" do
  user node[:mconf][:user]
  cwd Chef::Config[:file_cache_path]
  command "tar xzf #{node[:mconf][:live][:file]} --directory #{node[:mconf][:live][:deploy_dir]}/"
  action :run
  only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy record-and-playback" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/record-and-playback")
            FileUtils.remove_entry_secure "/usr/local/bigbluebutton/core/Gemfile", :force => true, :verbose => true
            FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/record-and-playback/core/Gemfile", "/usr/local/bigbluebutton/core/"
            FileUtils.remove_entry_secure "/usr/local/bigbluebutton/core/lib", :force => true, :verbose => true
            FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/record-and-playback/core/lib", "/usr/local/bigbluebutton/core/"
            FileUtils.remove_entry_secure "/usr/local/bigbluebutton/core/scripts", :force => true, :verbose => true
            FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/record-and-playback/core/scripts", "/usr/local/bigbluebutton/core/"
            FileUtils.remove_entry_secure "/etc/bigbluebutton/god", :force => true, :verbose => true
            FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/record-and-playback/core/god/god", "/etc/bigbluebutton/"
            FileUtils.remove_entry_secure "/etc/init.d/bbb-record-core", :force => true, :verbose => true
            FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/record-and-playback/core/god/initd.god", "/etc/init.d/bbb-record-core"
            FileUtils.rm_r Dir.glob("/var/bigbluebutton/playback/*"), :force => true, :verbose => true
            File.chmod(0755, "/etc/init.d/bbb-record-core")

            def deploy_recording_format(formats)
                formats.each do |format|
                    playback_dir = "#{node[:mconf][:live][:deploy_dir]}/record-and-playback/#{format}/playback/#{format}"
                    scripts_dir = "#{node[:mconf][:live][:deploy_dir]}/record-and-playback/#{format}/scripts"
                    FileUtils.cp_r playback_dir, "/var/bigbluebutton/playback/" unless not ::File.exists?(playback_dir)
                    FileUtils.cp_r Dir.glob("#{scripts_dir}/*"), "/usr/local/bigbluebutton/core/scripts/" unless not ::File.exists?(scripts_dir)
                    FileUtils.mkdir_p "/var/log/bigbluebutton/#{format}"
                end
            end

            if not node[:mconf][:recording_server][:enabled].nil? and node[:mconf][:recording_server][:enabled]
                Chef::Log.info("This is a Mconf-Live recording server")
                FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/record-and-playback/mconf/scripts/mconf-god-conf.rb", "/etc/bigbluebutton/god/conf/"
                FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/record-and-playback/mconf/scripts/mconf-decrypt.rb", "/usr/local/bigbluebutton/core/scripts/"

                deploy_recording_format(node[:mconf][:live][:default_playback])
            else
                Chef::Log.info("This is a Mconf-Live recorder")
                deploy_recording_format([ "mconf" ])
            end

            FileUtils.mv Dir.glob("/usr/local/bigbluebutton/core/scripts/*.nginx"), "/etc/bigbluebutton/nginx/"
            FileUtils.chown_R "tomcat6", "tomcat6", [ "/var/bigbluebutton/playback/", "/var/log/bigbluebutton/" ], :verbose => true
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

execute "install gems" do
  user "root"
  cwd "/usr/local/bigbluebutton/core/"
  command "bundle install"
  action :run
  only_if do File.exists?("/usr/local/bigbluebutton/core/Gemfile") and File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "generate recording server keys" do
    block do
        def execute(command)
            status = Open4::popen4(command) do | pid, stdin, stdout, stderr|
                Chef::Log.info("Executing: #{command}")

                output = stdout.readlines
                Chef::Log.info("stdout: #{Array(output).join()} ") unless output.empty?

                errors = stderr.readlines
                Chef::Log.error("stderr: #{Array(errors).join()}") unless errors.empty?
            end
            if not status.success?
                raise "Execution failed, raising an exception"
            end
        end

        execute("openssl genrsa -out #{node[:mconf][:recording_server][:private_key_path]} 2048")
        execute("openssl rsa -in #{node[:mconf][:recording_server][:private_key_path]} -out #{node[:mconf][:dir]}/public_key.pem -outform PEM -pubout")

        # The following code doesn't work because the RSA key generated by Ruby 
        # OpenSSL is formatted in a way that the openssl application doesn't
        # understand
        # http://stackoverflow.com/questions/4635837/invalid-public-keys-when-using-the-ruby-openssl-library
        #rsa_key = OpenSSL::PKey::RSA.new(2048)
        #private_key = rsa_key.to_pem
        #File.open("#{node[:mconf][:recording_server][:private_key_path]}", 'w') {|f| f.write(private_key) }
        #public_key = rsa_key.public_key.to_pem
        #node.set[:keys][:recording_server_public] = "#{public_key}"
    end
    only_if do node[:mconf][:recording_server][:enabled] and not File.exists?(node[:mconf][:recording_server][:private_key_path]) end
end

ruby_block "save public key" do
  block do
    node.set[:keys][:recording_server_public] = File.read("#{node[:mconf][:dir]}/public_key.pem")
  end
  only_if do node[:mconf][:recording_server][:enabled] and File.exists?("#{node[:mconf][:dir]}/public_key.pem") end
end

Dir["/var/bigbluebutton/published/**/metadata.xml"].each do |filename|
    execute "update server url metadata" do
        # extra escape needed
        command "sed -i 's \\(https\\?://[^/]*\\)/\\(mconf\\|presentation\\)/ #{node[:bbb][:server_url]}/\\2/ g' #{filename}"
        user "root"
        action :run
        only_if do File.exists?(filename) end
    end
end

#ruby_block "update server url metadata" do
#    block do
#            Chef::Log.info("Updating server URL on metadata: #{filename}")
            # this code doesn't work, trying something different
            #text = File.read(filename)
            #File.open("#{filename}", "w") { |file| file.puts text.gsub(/http(s?):\/\/([\w+.-]+)(\/mconf|\/playback)/, "#{node[:bbb][:server_url]}\\3") }
#            if not File.exists?("#{filename}.backup")
#                FileUtils.cp "#{filename}", "#{filename}.backup"
#            end
#            File.open("#{filename}", 'w') do |out|
#                out << File.open("#{filename}.backup").read.gsub(/http(s?):\/\/([\w+.-]+)(\/mconf|\/playback)/, "#{node[:bbb][:server_url]}\\3")
#            end
#        end
#    end
#    action :nothing
#end

# \TODO remove files from non recorded sessions
# \TODO create cron jobs to handle such files
ruby_block "remove raw data of encrypted recordings" do
    block do
        Dir["/var/bigbluebutton/published/mconf/*"].each do |dir|
            meeting_id = File.basename(dir)
            if not File.exists?("/var/bigbluebutton/recordings/raw/#{meeting_id}")
                Chef::Log.info "The recording #{meeting_id} is published so the video, audio and deskshare files aren't needed anymore"
                FileUtils.rm_r [ "/usr/share/red5/webapps/video/streams/#{meeting_id}",
                                 "/usr/share/red5/webapps/deskshare/streams/#{meeting_id}",
                                 Dir.glob("/var/freeswitch/meetings/#{meeting_id}*.wav") ], :force => true
            end
        end
    end
end

template "/usr/local/bigbluebutton/core/scripts/mconf.yml" do
  source "mconf.yml.erb"
  mode "0644"
  variables(
    :get_recordings_url => node[:mconf][:recording_server][:get_recordings_url],
    :private_key => node[:mconf][:recording_server][:private_key_path]
  )
  only_if do node[:mconf][:recording_server][:enabled] end
end

ruby_block "deploy apps" do
    block do
        %w{ bigbluebutton video deskshare sip }.each do |app|
            if File.exists?("#{node[:mconf][:live][:deploy_dir]}/apps/#{app}")
                Chef::Log.info("Deploying red5 app: #{app}")
                FileUtils.remove_entry_secure "/usr/share/red5/webapps/#{app}", :force => true, :verbose => true
                FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/apps/#{app}", "/usr/share/red5/webapps/"
            end
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
    # we need to notify some of the bigbluebutton resources because we just
    # overwrite all bbb-apps including the configuration files
    notifies :create, "template[deploy red5 deskshare conf]", :immediately
    notifies :create, "template[deploy red5 video conf]", :immediately
    notifies :create, "directory[video streams dir]", :immediately
end

ruby_block "deploy client" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/client")
            Chef::Log.info("Deploying client")
            FileUtils.remove_entry_secure "/var/www/bigbluebutton/client/", :force => true, :verbose => true
            FileUtils.cp_r "#{node[:mconf][:live][:deploy_dir]}/client", "/var/www/bigbluebutton/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy config" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/config")
            Chef::Log.info("Deploying config")
            FileUtils.cp_r Dir.glob("#{node[:mconf][:live][:deploy_dir]}/config/*"), "/usr/local/bin/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "deploy demo" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/demo") && File.exists?("/var/lib/tomcat6/webapps/demo/")
            Chef::Log.info("Deploying demo")
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/demo.war", :force => true, :verbose => true
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/demo/", :force => true, :verbose => true
            FileUtils.cp_r Dir.glob("#{node[:mconf][:live][:deploy_dir]}/demo/*"), "/var/lib/tomcat6/webapps/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

# if the demo was deployed without packages, this block will remove it
ruby_block "remove demo files" do
    block do
        FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/demo.war", :force => true, :verbose => true
        FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/demo/", :force => true, :verbose => true
    end
    only_if do not node[:bbb][:demo][:enabled] and File.exists?("/var/lib/tomcat6/webapps/demo/") end
    notifies :run, "execute[restart bigbluebutton]", :delayed
end

ruby_block "deploy web" do
    block do
        if File.exists?("#{node[:mconf][:live][:deploy_dir]}/web") && File.exists?("/var/lib/tomcat6/webapps/bigbluebutton/")
            Chef::Log.info("Deploying bigbluebutton-web")
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/bigbluebutton.war", :force => true, :verbose => true
            FileUtils.remove_entry_secure "/var/lib/tomcat6/webapps/bigbluebutton/", :force => true, :verbose => true
            FileUtils.cp_r Dir.glob("#{node[:mconf][:live][:deploy_dir]}/web/*"), "/var/lib/tomcat6/webapps/"
        end
    end
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

ruby_block "sleep until bigbluebutton-web is deployed" do
  block do
    %x(service tomcat6 start)
    count = 15
    while not File.exists?("/var/lib/tomcat6/webapps/bigbluebutton") and count > 0 do
      sleep 1.0
      count -= 1
    end
  end
  only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
end

# register deployed version
file "#{node[:mconf][:live][:deploy_dir]}/.deployed" do
  action :create
  content node[:mconf][:live][:version]
end

# restore salt and IP
execute "bbb-conf --setsalt #{node[:bbb][:salt]} || bbb-conf --setip #{node[:bbb][:server_addr]} || echo 'Return successfully'" do
    user "root"
    action :run
    only_if do File.exists?("#{node[:mconf][:live][:deploy_dir]}/.deploy_needed") end
    notifies :run, "execute[restart bigbluebutton]", :delayed
end

ruby_block "reset Mconf-Live force_deploy flag" do
    block do
        node.set[:mconf][:live][:force_deploy] = false
    end
    only_if do node[:mconf][:live][:force_deploy] end
end
