if [ x$1 != 'x-f' ]; then
  read -p "Are you sure? Old '$1' assets will be lost and overwritten. (y/n): " -r ;
  if [[ ! $REPLY =~ ^[Yy]$ ]] ;
  then
    exit 1
  fi
  VERSION=$1
else
  VERSION=$2
fi

s3cmd put -P -m application/x-gzip target/nxlog.tar.gz             s3://qubell-logging/$VERSION/nxlog.tar.gz
s3cmd put -P -m application/x-gzip target/logstash.tar.gz          s3://qubell-logging/$VERSION/logstash.tar.gz

s3cmd put -P -m application/javascript target/kibana-all.js        s3://qubell-logging/$VERSION/kibana-all.js

s3cmd put -P -m application/x-yaml manifests/logstash.yaml         s3://qubell-logging/$VERSION/logstash.yaml
s3cmd put -P -m application/x-yaml manifests/nxlog-example.yaml    s3://qubell-logging/$VERSION/nxlog-example.yaml
s3cmd put -P -m application/x-yaml manifests/nxlog-example.yaml    s3://qubell-logging/$VERSION/nxlog-example.v1.yaml
s3cmd put -P -m application/x-yaml manifests/nxlog-example.v2.yaml s3://qubell-logging/$VERSION/nxlog-example.v2.yaml