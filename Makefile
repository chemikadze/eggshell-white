all: target pack_cookbooks javascript

pack_cookbooks: target/logstash.tar.gz target/nxlog.tar.gz
.PHONY: pack_cookbooks

javascript: target/kibana-all.js
.PHONY: javascript

target:
	mkdir -p target

target/kibana-all.js: $(shell find widgets -type f -name '*.js')
	cd widgets; \
		pwd; \
		ls; \
		cat elastic.js elastic-jquery-client.js kibana.js > ../target/kibana-all.js

target/logstash.tar.gz: $(shell find cookbooks -type f)
	tar -czvpf target/logstash.tar.gz cookbooks/java cookbooks/logstash cookbooks/nginx cookbooks/yum

target/nxlog.tar.gz: $(shell find cookbooks -type f)
	tar -czvpf target/nxlog.tar.gz cookbooks/nxlog

clean:
	rm -rf target

