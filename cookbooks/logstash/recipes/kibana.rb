# Install Kibana UI

include_recipe "nginx"

template "/usr/share/nginx/html/kibana-master/src/app/dashboards/logstash.json" do
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
    mkdir -p /usr/share/nginx/html/kibana-master
    tar -xzf #{Chef::Config[:file_cache_path]}/kibana.tar.gz -C /usr/share/nginx/html/kibana-master --strip-components=1
  EOC
  action :nothing
  notifies :create, "template[/usr/share/nginx/html/kibana-master/src/app/dashboards/logstash.json]", :immediately
end

remote_file "#{Chef::Config[:file_cache_path]}/kibana.tar.gz" do
  source "https://github.com/elasticsearch/kibana/archive/9d6573e3d8130d722f71835957fcdf602ca1e18f.tar.gz"
  notifies :run, "bash[install kibana]", :immediately
end
