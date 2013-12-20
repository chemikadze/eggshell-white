all: target pack_cookbooks javascript

upload_as_latest: all
	./upload-assets.sh latest
.PHONY: upload_latest

upload_as_stable: all
	./upload-assets.sh stable
.PHONY: upload_stable

upload_new_version: all
	./upload-assets.sh -f $(shell git log -n 1 --pretty=format:%h)
.PHONY: upload_stable

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

SERVICE_FACTORY=cookbooks/resource_masher cookbooks/run_action_now cookbooks/unix_bin cookbooks/nginx cookbooks/service_factory

target/logstash.tar.gz: $(shell find cookbooks -type f)
	tar -czvpf target/logstash.tar.gz cookbooks/java cookbooks/ohai cookbooks/yum ${SERVICE_FACTORY} cookbooks/logstash

target/nxlog.tar.gz: $(shell find cookbooks -type f)
	tar -czvpf target/nxlog.tar.gz ${SERVICE_FACTORY} cookbooks/nxlog

clean:
	rm -rf target

