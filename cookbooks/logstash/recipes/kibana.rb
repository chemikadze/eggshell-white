# Install Kibana UI

include_recipe "nginx"

directory node['kibana']['install_root'] do
  owner 'root'
  group 'root'
  action :create
end

template "#{node['kibana']['install_root']}/app/dashboards/logstash.json" do
  user "root"
  group "root"
  mode "0644"
  source "logstash.json"
  action :nothing
end

template "#{node['kibana']['install_root']}/config.js" do
  user "root"
  group "root"
  mode "0644"
  source "kibana-config.js.erb"
  action :nothing
end

bash "install kibana" do
  user "root"
  group "root"
  code <<-EOC
    tar -xzf #{Chef::Config[:file_cache_path]}/kibana.tar.gz -C #{node['kibana']['install_root']} --strip-components=1
  EOC
  action :nothing
  notifies :create, "template[#{node['kibana']['install_root']}/app/dashboards/logstash.json]", :immediately
  notifies :create, "template[#{node['kibana']['install_root']}/config.js]", :immediately
end

remote_file "#{Chef::Config[:file_cache_path]}/kibana.tar.gz" do
  source "https://download.elasticsearch.org/kibana/kibana/kibana-#{node['kibana']['version']}.tar.gz"
  notifies :run, "bash[install kibana]", :immediately
end

template File.join(node['nginx']['dir'], "sites-available", "kibana") do
  user "root"
  group "root"
  mode "0644"
  source "kibana.site.erb"
  action :create
  variables({
    :serve_ganglia => (not node['logstash']['skip_monitor']),
    :fastcgiconf => (if node[:platform] == "ubuntu" or node[:platform] == "debian" then "fastcgi_params" else "fastcgi.conf" end)
    })
end

file File.join(node['nginx']['dir'], "conf.d", "default.conf") do
  action :delete
end

nginx_site "default" do
  enable false
  timing :immediately
end

nginx_site "kibana" do
  timing :immediately
end

service 'nginx' do
  supports :status => true, :restart => true, :reload => true
  action   :start
end
