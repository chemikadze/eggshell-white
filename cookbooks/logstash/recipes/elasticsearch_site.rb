include_recipe "nginx"

if node['elasticsearch']['serve_ssl'] then

  template File.join(node['nginx']['dir'], "sites-available", "elasticsearch") do
    user "root"
    group "root"
    mode "0644"
    source "elasticsearch.site.erb"
    action :create
  end

  nginx_site "elasticsearch" do
    timing :immediately
  end

end