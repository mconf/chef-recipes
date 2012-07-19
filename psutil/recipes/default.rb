package "python"
package "python-dev"
package "subversion"
package "gcc"

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
    notifies :run, 'execute[psutil_install]', :immediately
end

#install psutil as root
execute "psutil_install" do
    action :nothing
    user "root"
    cwd "/var/mconf/tools/psutil/"
    command "python setup.py install"
    creates "/usr/local/lib/python2.6/dist-packages/psutil/"
end
