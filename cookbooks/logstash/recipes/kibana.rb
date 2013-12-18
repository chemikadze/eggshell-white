# Install Kibana UI

include_recipe "nginx"

directory node['kibana']['install_root'] do
  owner 'root'
  group 'root'
  action :create
end

template "#{node['kibana']['install_root']}/kibana-master/src/app/dashboards/logstash.json" do
  user "root"
  group "root"
  mode "0644"
  source "logstash.json"
  action :nothing
end

bash "install kibana" do
  user "root"
  group "root"
  code <<-EOC
    tar -xzf #{Chef::Config[:file_cache_path]}/kibana.tar.gz -C #{node['kibana']['install_root']}
  EOC
  action :nothing
  notifies :create, "template[#{node['kibana']['install_root']}/kibana-master/src/app/dashboards/logstash.json]", :immediately
end

remote_file "#{Chef::Config[:file_cache_path]}/kibana.tar.gz" do
  source "https://github.com/elasticsearch/kibana/archive/9d6573e3d8130d722f71835957fcdf602ca1e18f.tar.gz"
  notifies :run, "bash[install kibana]", :immediately
end

template File.join(node['nginx']['dir'], "sites-available", "kibana") do
  user "root"
  group "root"
  mode "0644"
  source "kibana.site.erb"
  action :create
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
