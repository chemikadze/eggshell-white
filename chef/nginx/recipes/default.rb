# Install Nginx from CentAlt repository

relnum = node['platform_version'].to_i

yum_repository "CentALT" do
  description "CentALT Packages for Enterprise Linux #{relnum} - $basearch"
  url "http://centos.alt.ru/repository/centos/#{relnum}/$basearch/"
  enabled 1
end

package "nginx-stable"

service "nginx" do
  action [ :enable, :start ]
end
