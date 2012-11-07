version = nil
if File.exists?("/var/www/bigbluebutton/client/conf/config.xml")
    version = `cat /var/www/bigbluebutton/client/conf/config.xml | grep '<version>' | sed 's:.*<version>\\(.*\\)</version>.*:\\1:g'`.strip!
end

# remove some stuff related to the previous deploy bbb0.8-mconf-0.1
if "#{version}" == "bbb0.8-mconf-0.1 - Mconf Node (mconf.org)"
    users = `cat /etc/passwd | cut -d: -f1`.split()

    # remove the cron jobs
    users.each do |usr|
      %w{ /usr/bin/live-notes-server.sh ~/tools/nagios-etc/cli/performance_report.py ~/tools/nagios-etc/cli/check_bbb_salt.sh }.each do |cmd|
        execute "remove #{cmd} cronjob as #{usr}" do
          user "#{usr}"
          command "crontab -l | grep -v '#{cmd}' > /tmp/cron.jobs; crontab /tmp/cron.jobs; rm /tmp/cron.jobs"
          action :run
        end
      end
    end

    # kill the related processes
    %w{ performance_report.py live-notes-server.sh sbt-launch.jar }.each do |proc|
      execute "kill process #{proc}" do
        command "ps ax | grep #{proc} | grep -v grep | awk '{print $1}' | xargs kill; exit 0"
        user "root"
      end
    end

    # remove the applications placed into /usr/bin
    %w{ /usr/bin/sbt-launch.jar /usr/bin/sbt /usr/bin/live-notes-server.sh }.each do |f|
      file "#{f}" do
        action :delete
      end
    end

    # remove the source folders
    users.each do |usr|
      %w{ tools downloads .ivy2 .sbt }.each do |dir|
        directory "/home/#{usr}/#{dir}/" do
          action :delete
          recursive true
        end
      end
    end
end
