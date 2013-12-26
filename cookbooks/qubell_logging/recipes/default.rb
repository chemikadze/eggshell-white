user = node['qubell_logging']['user']
home_dir = node.automatic['etc']['passwd'][user]['dir']

node.default['qubell_logging']['group'] = user

node.default['qubell_logging']['root'] = File.join(home_dir, '.undeploy.me/nxlog')
node.default['qubell_logging']['monitor_dir'] = File.join(home_dir, '.undeploy.me')

%w{user group root monitor_dir consumer}.each do |attribute|
  node.override['nxlog'][attribute] = node['qubell_logging'][attribute]
end

include_recipe 'nxlog::logger'