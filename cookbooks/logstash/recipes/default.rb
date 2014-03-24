# Install logstash standalone

require 'uri'
require 'open-uri'
include_recipe "java"
include_recipe "logstash::kibana"
include_recipe "logstash::elasticsearch_site"
include_recipe "service_factory"

rootdir = "/var/lib/logstash"

loglevels = {
  "WARN" => "",
  "INFO" => "-v",
  "DEBUG" => "-vv",
  "TRACE" => "-vvv"
}
loglevels.default = ""

directory rootdir do
  owner node.logstash.user
  group node.logstash.group
  mode "0755"
  action :create
end

node['elasticsearch']['path'].each_value do |path|
  directory path do
    owner node.logstash.user
    group node.logstash.group
    mode "0755"
    recursive true
    action :create
  end
end

directory node["logstash"]["logs"] do
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
  source "https://download.elasticsearch.org/logstash/logstash/logstash-#{node['logstash']['version']}-flatjar.jar"
  owner node.logstash.user
  group node.logstash.group
  mode "0644"
  action :create
end


inputs = []
if node['logstash']['amqp_url'] then
  amqp_uri = URI(node['logstash']['amqp_url'])
  inputs.push "rabbitmq" => {
    :host => amqp_uri.host,
    :port => (amqp_uri.port or 5261),
    :user => (amqp_uri.user or "guest"),
    :password => (amqp_uri.password or "guest"),
    :vhost => URI::decode(amqp_uri.path[1..-1]),
    :type => "portal",
    :queue => node['logstash']['amqp_queue'],
    :passive => true,
    :durable => true,
    :auto_delete => false,
    :exclusive => false,
    :ssl => false
  }
end

template "#{rootdir}/logstash.conf" do
  owner node.logstash.user
  group node.logstash.group
  mode "0644"
  source "logstash.conf.erb"
  variables "inputs" => inputs
end

template "#{node['elasticsearch']['path']['config']}/elasticsearch.yml" do
  owner node.logstash.user
  group node.logstash.group
  mode "0644"
  source "elasticsearch.yml.erb"
end

service_factory "logstash" do
  service_desc "Lostash and Elasticsearch"
  exec "/usr/bin/java"
  exec_args [
    "-Des.path.home=#{node['elasticsearch']['path']['home']}",
    "-Des.path.config=#{node['elasticsearch']['path']['config']}",
    "-jar #{rootdir}/logstash.jar",
    "agent",
    "-f #{rootdir}/logstash.conf",
    "--log #{node['logstash']['logs']}/logstash.log",
    loglevels[node['logstash']['loglevel']]
  ] + node['logstash']['extra_args']
  after_start "sleep 300" # logstash startup is very slow
  run_user node.logstash.user
  run_group node.logstash.group
  action [:create, :enable, :start]
end

