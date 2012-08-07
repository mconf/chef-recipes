%w{ "/usr/bin/live-notes-server.sh" "~/tools/nagios-etc/cli/performance_report.py" "~/tools/nagios-etc/cli/check_bbb_salt.sh" }.each do |cmd|
  %w{ "root" "mconf"}.each do |usr|
    cron "remove #{cmd} cronjob as #{usr}" do
      user usr
      command cmd
      action :delete
    end
  end
end

%{ "/usr/bin/sbt-launch.jar" "/usr/bin/sbt" "/usr/bin/live-notes-server.sh" }.each do |f|
  file f do
    action :delete
  end
end

`cat /etc/passwd | cut -d: -f1`.split().each do |usr|
  directory "/home/#{usr}/tools/"
  action :delete
  recursive true
end

