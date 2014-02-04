TMPDIR=${TMPDIR:-/tmp/}
NXLOG_ROOT=${NXLOG_ROOT:-~/.undeploy.me/nxlog}
NXLOG_MONITOR_DIR=${NXLOG_MONITOR_DIR:-~/.undeploy.me}
NXLOG_CONSUMER=${NXLOG_CONSUMER:-localhost}
NXLOG_RELEASE=${NXLOG_RELEASE:-latest}
NXLOG_REPO=${NXLOG_REPO:-http://qubell-logging.s3.amazonaws.com/$NXLOG_RELEASE}
NXLOG_REGISTRY=${NXLOG_ROOT}/registry.txt

set -E

function detect_system # ()
{
  if [ -f /etc/redhat-release ]; then
    VER=$(cat /etc/redhat-release | sed -Ee 's/.*([0-9]\.[0-9]).*/\1/g')
    echo centos-$VER-$(uname -m)
  else
    echo "Unsupported distro" 1>&2
    exit 1
  fi
}

function install_nxlog
{
  mkdir -p $NXLOG_ROOT
  mkdir -p $NXLOG_ROOT/spool
  mkdir -p $NXLOG_ROOT/cache
  mkdir -p $NXLOG_ROOT/var
  wget $NXLOG_REPO/nxlog-static-$(detect_system).tar.gz -O $TMPDIR/nxlog.tar.gz
  tar xzvpf $TMPDIR/nxlog.tar.gz -C $NXLOG_ROOT --strip-components=1
}

function register_qubell_path # (logger_host, path)
{
  echo "qubell $1 $2" >> $NXLOG_REGISTRY
}

function register_user_path # (logger_host, path...)
{
  HOST=$1
  while [ ! "x$2" == "x" ]; do
    echo "file   $HOST $2" >> $NXLOG_REGISTRY
    shift
  done
}

function deregister_single_path # (logger_host, path)
{
  if grep -n "$1 $2" $NXLOG_REGISTRY 2>&1 1>/dev/null; then
    /bin/cp -f $NXLOG_REGISTRY $NXLOG_REGISTRY~
    (
      LINE=$(grep -n "$1 $2" $NXLOG_REGISTRY~ | head -1 | cut -f1 -d:)
      head -n $(expr $LINE - 1 ) $NXLOG_REGISTRY~ 2>/dev/null
      tail -n +$(expr $LINE + 1 ) $NXLOG_REGISTRY~ 2>/dev/null
    ) > $NXLOG_REGISTRY
  fi
}

function deregister_path # (logger_host, path...)
{
  HOST=$1
  while [ ! "x$2" == "x" ]; do
    deregister_single_path $HOST "$2"
    shift
  done
}

function show_registry
{
  cat $NXLOG_REGISTRY
}

function compile_registry
{
  (
    cat <<EOF
########################################
# Generated automatically!             #
########################################
define ROOTDIR $NXLOG_ROOT

########################################
# Global directives                    #
########################################
ModuleDir %ROOTDIR%
LogFile %ROOTDIR%/var/nxlog.log
PidFile %ROOTDIR%/var/nxlog.pid
LogLevel INFO
SpoolDir %ROOTDIR%/spool
CacheDir %ROOTDIR%/cache

########################################
# Modules                              #
########################################
<Extension json>
    Module      xm_json
</Extension>
EOF

    cat $NXLOG_REGISTRY | while read TARGET_TYPE LOGGER_HOST TARGET_PATH; do
      TARGET_ID=$(head -c 100 /dev/urandom | base64 | sed 's/[+=/A-Z]//g' | tail -c 9)
      cat <<EOF

############################################################
# TYPE: $TARGET_TYPE    PATH: $TARGET_PATH    HOST: $LOGGER_HOST
############################################################

EOF
      case $TARGET_TYPE in
        qubell)
          cat <<EOF
<Input job_stdout_$TARGET_ID>
    Module im_file
    File "$TARGET_PATH/*.out"
    SavePos TRUE
    Recursive TRUE
    Exec \$Message = \$raw_event;
    Exec \$FileName = substr(file_name(), size("$TARGET_PATH")+1);
    Exec \$Stream = "stdout";
    Exec to_json();
</Input>

<Input job_stderr_$TARGET_ID>
    Module im_file
    File "$TARGET_PATH/*.err"
    SavePos TRUE
    Recursive TRUE
    Exec \$Message = \$raw_event;
    Exec \$FileName = substr(file_name(), size("$TARGET_PATH")+1);
    Exec \$Stream = "stderr";
    Exec to_json();
</Input>

<Processor stderr_buffer_$TARGET_ID>
    Module      pm_buffer
    # 8Mb buffer
    MaxSize 8192
    Type Mem
    # warn at 7M
    WarnLimit 7000
</Processor>

<Processor stdout_buffer_$TARGET_ID>
    Module      pm_buffer
    # 8Mb buffer
    MaxSize 8192
    Type Mem
    # warn at 7M
    WarnLimit 7000
</Processor>

<Output log_ssl_$TARGET_ID>
    Module  om_ssl
    Host    $LOGGER_HOST
    Port    8514
    AllowUntrusted TRUE
</Output>

<Route stderr_$TARGET_ID>
    Path    job_stdout_$TARGET_ID => stdout_buffer_$TARGET_ID => log_ssl_$TARGET_ID
</Route>

<Route stdout_$TARGET_ID>
    Path    job_stderr_$TARGET_ID => stderr_buffer_$TARGET_ID => log_ssl_$TARGET_ID
</Route>
EOF
        ;;

        file)
          cat <<EOF
<Input job_file_$TARGET_ID>
    Module im_file
    File "$TARGET_PATH"
    SavePos TRUE
    Recursive TRUE
    Exec \$Message = \$raw_event;
    Exec \$FileName = substr(file_name(), size("$TARGET_PATH")+1);
    Exec \$Stream = "stdout";
    Exec to_json();
</Input>

<Processor file_buffer_$TARGET_ID>
    Module      pm_buffer
    # 8Mb buffer
    MaxSize 8192
    Type Mem
    # warn at 7M
    WarnLimit 7000
</Processor>

<Output log_ssl_$TARGET_ID>
    Module  om_ssl
    Host    $LOGGER_HOST
    Port    8514
    AllowUntrusted TRUE
</Output>

<Route file_$TARGET_ID>
    Path    job_file_$TARGET_ID => file_buffer_$TARGET_ID => log_ssl_$TARGET_ID
</Route>
EOF
        ;;
      esac
    done
  ) > $NXLOG_ROOT/nxlog.conf
}

function start_service # ()
{
  if [ -f $NXLOG_ROOT/var/nxlog.pid ] && ps $(cat $NXLOG_ROOT/var/nxlog.pid) 2>&1 1>/dev/null; then
    echo "NXLog already running with PID $(cat $NXLOG_ROOT/var/nxlog.pid). Reloading configuration."
    $NXLOG_ROOT/nxlog -r -c $NXLOG_ROOT/nxlog.conf
  else
    $NXLOG_ROOT/nxlog -c $NXLOG_ROOT/nxlog.conf
  fi
}

function install # (consumer, monitor_dir)
{
  if [ -d $NXLOG_ROOT ]; then
    echo "NXLog already installed in $NXLOG_ROOT"
  else
    install_nxlog
  fi
  register_qubell_path ${1:-$NXLOG_CONSUMER} ${2:-$NXLOG_MONITOR_DIR}
  compile_registry
  start_service
}

### main
###

CMD=$1
if [ "x$CMD" != "x" ] && declare -F $CMD 2>&1 1>/dev/null ; then
  shift
  $CMD "$@"
else
  cat <<EOF
  Usage:
    $0 install MONITOR_DIR
        Install, configure and start nxlog.

    $0 start_service
        Start installed service.

    $0 show_registry
    $0 register_qubell_path LOGGER_HOST PATH
    $0 register_user_path LOGGER_HOST PATH [PATH...]
    $0 deregister_path LOGGER_HOST PATH [PATH...]
        View and edit list of logged entities.

    $0 compile_registry
        Generates nxlog configuration from registry.

EOF
fi
