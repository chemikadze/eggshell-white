BUCKET=qubell-logging

usage() {
  cat <<EOF
Usage:
  $0 [FLAGS] VERSION

  Flags:
    -f, --force       do not ask before upload
    --travis          use travis-artifacts instead of s3cmd
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
    -f|--force)
      FORCE=1
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
    --travis)
      USE_TRAVIS=1
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

if [ ! -z $USE_TRAVIS ]; then
  upload() {
    (
      cd $(dirname $1)
      STRIPPED_PATH=$(basename $1)
      TARGET_PATH=$VERSION/$(dirname $2 | sed -e 's/^\.$//')
      # travis-artifacts uploads artifact with name $TARGET_PATH/$STRIPPED_PATH
      travis-artifacts upload --path $STRIPPED_PATH --target-path $TARGET_PATH
    )
  }
else
  upload() {
    s3cmd put -P $1 s3://qubell-logging/$VERSION/$2
  }
fi

if [ -z $VERSION ]; then
  usage
  exit 1
fi

if [ -z $FORCE ]; then
  read -p "Are you sure? Old '$VERSION' assets will be lost and overwritten. (y/n): " -r ;
  if [[ ! $REPLY =~ ^[Yy]$ ]] ;
  then
    exit 1
  fi
fi

if [ ! -z $WITH_COOKBOOKS ]; then
  upload target/nxlog.tar.gz    nxlog.tar.gz
  upload target/logstash.tar.gz logstash.tar.gz
fi

if [ ! -z $WITH_WIDGETS ]; then
  upload target/kibana-all.js kibana-all.js
fi

if [ ! -z $WITH_MANIFESTS ]; then
  upload manifests/logstash.yaml logstash.yaml
  upload manifests/logstash-static.yaml  logstash-static.yaml
  upload manifests/nxlog-example.yaml    nxlog-example.yaml
  upload manifests/nxlog-example.yaml    nxlog-example.v1.yaml
  upload manifests/nxlog-example.v2.yaml nxlog-example.v2.yaml
fi

if [ ! -z $WITH_NXLOG_SCRIPTS ]; then
  upload nxlog/setup-nxlog.sh setup-nxlog.sh
fi

if [ ! -z $WITH_NXLOG_TARBALLS ]; then
  for i in target/nxlog-static*.tar.gz; do
    upload $i ${i#target/}
  done
fi

