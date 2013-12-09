include_recipe "nxlog"

template ::File.join(node.nxlog.root, "nxlog.conf") do
  owner node.nxlog.user
  group node.nxlog.group
  mode "0644"
  source "nxlog.conf.erb"
  notifies :run, "bash[nxlog restart]"
end
