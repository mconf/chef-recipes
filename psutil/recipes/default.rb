
directory "/var/mconf/tools/psutil" do
  mode "0775"
  owner "mconf"
  recursive true
end

#get psutil source
subversion "psutil_get_source" do
  repository "http://psutil.googlecode.com/svn/trunk"
  revision "HEAD"
  destination "/var/mconf/tools/psutil/"
  action :sync
end

#install psutil as root
script "psutil_install" do
        interpreter "bash"
        user "root"
        cwd "/var/mconf/tools/psutil/"
        not_if do File.exists?('/usr/local/lib/python2.6/dist-packages/psutil/') end
        code <<-EOH
        python setup.py install
        EOH
end
