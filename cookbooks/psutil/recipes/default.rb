%w{ python python-dev subversion gcc }.each do |pkg|
  package pkg do
    action :install
  end
end

directory "#{Chef::Config[:file_cache_path]}/psutil" do
  owner "root"
  recursive true
end

subversion "get psutil source code" do
    repository "http://psutil.googlecode.com/svn/trunk"
#    revision "HEAD"
    revision "1400"
    destination "#{Chef::Config[:file_cache_path]}/psutil/"
    action :sync
    notifies :run, 'execute[install psutil]', :immediately
end

execute "install psutil" do
    action :nothing
    user "root"
    cwd "#{Chef::Config[:file_cache_path]}/psutil/"
    command "python setup.py install"
end
