# Install logstash standalone

include_recipe "java"
include_recipe "logstash::kibana"
include_recipe "logstash::elasticsearch_site"

rootdir = "/var/lib/logstash"

directory rootdir do
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

bash "start logstash" do
  user node.logstash.user
  group node.logstash.group
  cwd "/tmp"
  code <<-EOC
    killall java
    /usr/bin/setsid /usr/bin/nohup java -jar #{rootdir}/logstash.jar agent -f #{rootdir}/logstash.conf &>/tmp/logstash.log &
    # Pause to allow logstash to start and initialize, it is really slow
    sleep 300
  EOC
end


