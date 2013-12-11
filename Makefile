all: target cookbooks javascript

cookbooks: target/logstash.tar.gz target/nxlog.tar.gz
.PHONY: cookbooks

javascript: target/kibana-all.js
.PHONY: javascript

target:
	mkdir -p target

target/kibana-all.js: $(shell find widgets -type f -name '*.js')
	cd widgets; \
		pwd; \
		ls; \
		cat elastic.js elastic-jquery-client.js kibana.js > ../target/kibana-all.js

target/logstash.tar.gz: $(shell find chef -type f)
	tar -C chef -czvpf target/logstash.tar.gz java logstash nginx yum

target/nxlog.tar.gz: $(shell find chef -type f)
	tar -C chef -czvpf target/nxlog.tar.gz nxlog

clean:
	rm -rf target

