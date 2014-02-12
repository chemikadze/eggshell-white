usage() {
  cat <<EOF
Usage:
  $0 [FLAGS] VERSION

  Flags:
    -f, --force       do not ask before upload
    --nxlog-scripts   upload nxlog tarballs
    --nxlog-tarballs  upload nxlog tarballs
    --widgets         upload widget assets
    --manifests       upload manifests
    --cookbooks       upload cookbooks
EOF
}

if [ -z $1 ]; then
  usage
  exit 0
fi

while [ ! -z $1 ]; do
  case $1 in
    -f | --force)
      read -p "Are you sure? Old '$1' assets will be lost and overwritten. (y/n): " -r ;
      if [[ ! $REPLY =~ ^[Yy]$ ]] ;
      then
        exit 1
      fi
      ;;
    --nxlog-scripts)
      WITH_NXLOG_SCRIPTS=1
      ;;
    --nxlog-tarballs)
      WITH_NXLOG_TARBALLS=1
      ;;
    --widgets)
      WITH_WIDGETS=1
      ;;
    --manifests)
      WITH_MANIFESTS=1
      ;;
    --cookbooks)
      WITH_COOKBOOKS=1
      ;;
    -*)
      usage
      exit 1
      ;;
    *)
      VERSION=$1
      ;;
  esac
  shift
done

if [ -z $VERSION ]; then
  usage
  exit 1
fi

if [ ! -z $WITH_COOKBOOKS ]; then
  s3cmd put -P -m application/x-gzip target/nxlog.tar.gz             s3://qubell-logging/$VERSION/nxlog.tar.gz
  s3cmd put -P -m application/x-gzip target/logstash.tar.gz          s3://qubell-logging/$VERSION/logstash.tar.gz
fi

if [ ! -z $WITH_WIDGETS ]; then
  s3cmd put -P -m application/javascript target/kibana-all.js        s3://qubell-logging/$VERSION/kibana-all.js
fi

if [ ! -z $WITH_MANIFESTS ]; then
  s3cmd put -P -m application/x-yaml manifests/logstash.yaml         s3://qubell-logging/$VERSION/logstash.yaml
  s3cmd put -P -m application/x-yaml manifests/nxlog-example.yaml    s3://qubell-logging/$VERSION/nxlog-example.yaml
  s3cmd put -P -m application/x-yaml manifests/nxlog-example.yaml    s3://qubell-logging/$VERSION/nxlog-example.v1.yaml
  s3cmd put -P -m application/x-yaml manifests/nxlog-example.v2.yaml s3://qubell-logging/$VERSION/nxlog-example.v2.yaml
fi

if [ ! -z $WITH_NXLOG_SCRIPTS ]; then
  s3cmd put -P nxlog/setup-nxlog.sh s3://qubell-logging/$VERSION/setup-nxlog.sh
fi

if [ ! -z $WITH_NXLOG_TARBALLS ]; then
  for i in target/nxlog-static*.tar.gz; do
    s3cmd put -P -m application/x-gzip $i s3://qubell-logging/$VERSION/${i#target/}
  done
fi

