# Install logstash standalone

include_recipe "java"
include_recipe "logstash::kibana"
include_recipe "logstash::elasticsearch_site"
include_recipe "service_factory"

rootdir = "/var/lib/logstash"

directory rootdir do
  owner node.logstash.user
  group node.logstash.group
  mode "0755"
  action :create
end

directory "/data" do
  owner node.logstash.user
  group node.logstash.group
  mode "0755"
  action :create
end

bash "generate logstash certificate" do
  not_if { File.exists? ::File.join(rootdir, "server.pem") }
  cwd rootdir
  user node.logstash.user
  group node.logstash.group
  code <<-EOC
    openssl genrsa -out #{::File.join(rootdir, "server.key")} 2048
    openssl req -new -x509 -extensions v3_ca -days 1100 -subj "/CN=Logstash" -nodes -out #{::File.join(rootdir, "server.pem")} -key #{::File.join(rootdir, "server.key")}
  EOC
end

remote_file "#{rootdir}/logstash.jar" do
  source "http://logstash.objects.dreamhost.com/release/logstash-1.1.13-flatjar.jar"
  owner node.logstash.user
  group node.logstash.group
  mode "0644"
  action :create
end

template "#{rootdir}/logstash.conf" do
  owner node.logstash.user
  group node.logstash.group
  mode "0644"
  source "logstash.conf.erb"
end

service_factory "logstash" do
  service_desc "Lostash and Elasticsearch"
  exec "/usr/bin/java"
  exec_args [
    "-jar #{rootdir}/logstash.jar",
    "agent",
    "-f #{rootdir}/logstash.conf"
  ]
  after_start "sleep 300" # logstash startup is very slow
  run_user node.logstash.user
  run_group node.logstash.group
  action [:create, :enable, :start]
end

