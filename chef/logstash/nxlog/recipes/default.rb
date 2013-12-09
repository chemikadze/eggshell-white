# ADP repository

case node[:platform]
when "redhat", "centos"
  relnum = node['platform_version'].to_i

  #get the metadata
  execute "yum -q makecache" do
    action :nothing
  end
  #reload internal Chef yum cache
  ruby_block "reload-internal-yum-cache" do
    block do
      Chef::Provider::Package::Yum::YumCache.instance.reload
    end
    action :nothing
  end

  #write out the file
  template "/etc/yum.repos.d/ADP.repo" do
    source "ADP.repo.erb"
    mode "0644"
    variables({
                :relnum => relnum
              })
    notifies :run, resources(:execute => "yum -q makecache"), :immediately
    notifies :create, resources(:ruby_block => "reload-internal-yum-cache"), :immediately
  end

end

directory node.nxlog.root do
  owner node.nxlog.user
  group node.nxlog.group
  action :create
end

%w{var spool cache}.each do |dir|
  directory ::File.join(node.nxlog.root, dir) do
    owner node.nxlog.user
    group node.nxlog.group
    action :create
  end
end

bash "generate certificate" do
  not_if { File.exists? ::File.join(node.nxlog.root, "server.pem") }
  user node.nxlog.user
  group node.nxlog.group
  cwd node.nxlog.root
  code <<-EOC
    openssl genrsa -out #{::File.join(node.nxlog.root, "server.key")} 2048
    openssl req -new -x509 -extensions v3_ca -days 1100 -subj "/CN=NXLog" -nodes -out #{::File.join(node.nxlog.root, "server.pem")} -key #{::File.join(node.nxlog.root, "server.key")}
  EOC
end

package "nxlog-ce"

bash "nxlog restart" do
  user node.nxlog.user
  group node.nxlog.group
  cwd node.nxlog.root
  code <<-EOC
    killall -9 nxlog
    nxlog -c #{::File.join(node.nxlog.root, "nxlog.conf")}
  EOC
  action :nothing
end

