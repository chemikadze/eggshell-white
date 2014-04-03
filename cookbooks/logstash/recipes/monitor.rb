package "rrdtool"

case node[:platform]
when "ubuntu", "debian"
  package "ganglia-monitor"
  package "gmetad"
  package "php5-fpm"
  service_name = "ganglia-monitor"
when "redhat", "centos", "fedora"
  include_recipe "yum::epel"
  package "ganglia-gmond"
  package "ganglia-gmetad"  
  package "php-fpm"  
  service_name = "gmond"
end

service "gmetad" do
  supports :restart => true
  action [ :enable, :start ]
end

service service_name do
  pattern "gmond"
  supports :restart => true
  action [ :enable, :start ]
end

fpm_conf = "/etc/php-fpm.d/www.conf"
execute "configure php-fpm" do
  command "cp #{fpm_conf} #{fpm_conf}.tmp && sed -e 's|^listen =.*$|listen = /var/run/php-fpm/php-fpm.sock|' < #{fpm_conf}.tmp > #{fpm_conf}"
end

service "php-fpm" do
  action :restart
end

remote_file "/usr/src/ganglia-#{node['ganglia']['version']}.tar.gz" do
  source node['ganglia']['uri']
  checksum node['ganglia']['checksum']
end

directory node['ganglia']['root']
directory node['ganglia']['root'] + "/www"

bash "install ganglia-web" do
  code <<-EOF
  tar xzf /usr/src/ganglia-#{node['ganglia']['version']}.tar.gz -C #{node['ganglia']['root']}/www --strip-components=1 ganglia-#{node['ganglia']['version']}/web 
  mv #{node['ganglia']['root']}/www/web #{node['ganglia']['root']}/www/ganglia 
  sed -e 's|@varstatedir@|/var/lib/|' < #{node['ganglia']['root']}/www/ganglia/conf.php.in > #{node['ganglia']['root']}/www/ganglia/conf.php
  chown apache:apache -R #{node['ganglia']['root']}/www
  chmod 0555 -R #{node['ganglia']['root']}/www
  EOF
  cwd "/usr/src"
  creates node['ganglia']['root'] + "/www/ganglia"
end

 
