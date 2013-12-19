default['kibana']['serve_ssl'] = false

default['kibana']['install_root']             = '/var/lib/kibana'
default['kibana']['ssl_certificate']          = '/var/lib/logstash/server.pem' # TODO
default['kibana']['ssl_certificate_key']      = '/var/lib/logstash/server.key' # TODO

default['logstash']['install_root']           = '/var/lib/logstash'
default['logstash']['ssl_certificate']        = '/var/lib/logstash/server.pem'
default['logstash']['ssl_certificate_key']    = '/var/lib/logstash/server.key' 

default['elasticsearch']['serve_ssl'] = false
default['elasticsearch']['proxy_port']          = 9201
default['elasticsearch']['ssl_certificate']     = '/var/lib/logstash/server.pem' # TODO
default['elasticsearch']['ssl_certificate_key'] = '/var/lib/logstash/server.key' # TODO