include_recipe "nxlog"

template ::File.join(node.nxlog.root, "nxlog.conf") do
  owner node.nxlog.user
  group node.nxlog.group
  mode "0644"
  source "nxlog.conf.consumer.erb"
  notifies :run, "bash[nxlog restart]"
end

bash "http server run" do
  user node.nxlog.user
  group node.nxlog.group
  cwd ::File.join(node.nxlog.root, "var")
  code <<-EOC
    killall python
    /usr/bin/setsid /usr/bin/nohup python -m SimpleHTTPServer &>python.log &
  EOC
end
