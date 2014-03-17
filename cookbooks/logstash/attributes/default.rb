default['kibana']['serve_ssl'] = false

default['kibana']['install_root']             = '/var/lib/kibana'
default['kibana']['ssl_certificate']          = '/var/lib/logstash/server.pem' # TODO
default['kibana']['ssl_certificate_key']      = '/var/lib/logstash/server.key' # TODO
default['kibana']['version']                  = '9d6573e3d8130d722f71835957fcdf602ca1e18f'

default['logstash']['version']                = '1.3.3'
default['logstash']['install_root']           = '/var/lib/logstash'
default['logstash']['logs']                   = '/var/log/logstash'
default['logstash']['ssl_certificate']        = '/var/lib/logstash/server.pem'
default['logstash']['ssl_certificate_key']    = '/var/lib/logstash/server.key'
default['logstash']['loglevel']               = 'INFO' # ERROR, INFO, VERBOSE, TRACE
default['logstash']['extra_args']             = []

default['elasticsearch']['serve_ssl']           = false
default['elasticsearch']['proxy_port']          = 9201
default['elasticsearch']['ssl_certificate']     = '/var/lib/logstash/server.pem' # TODO
default['elasticsearch']['ssl_certificate_key'] = '/var/lib/logstash/server.key' # TODO
default['elasticsearch']['path']['home']        = '/var/lib/elasticsearch'
default['elasticsearch']['path']['data']        = '/var/lib/elasticsearch/data'
default['elasticsearch']['path']['logs']        = '/var/log/elasticsearch'
