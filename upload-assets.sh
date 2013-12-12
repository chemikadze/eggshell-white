if [ x$1 != 'x-f' ]; then
  read -p "Are you sure? Old 'stable' assets will be lost and overwritten. (y/n): " -r ;
  if [[ ! $REPLY =~ ^[Yy]$ ]] ;
  then 
    exit 1
  fi  
  VERSION=$1
else
  VERSION=$2
fi

s3cmd put -P -m application/x-gzip target/nxlog.tar.gz s3://qubell-logging/$VERSION/nxlog.tar.gz
s3cmd put -P -m application/x-gzip target/logstash.tar.gz s3://qubell-logging/$VERSION/logstash.tar.gz
s3cmd put -P -m application/javascript target/kibana-all.js s3://qubell-logging/$VERSION/kibana-all.js