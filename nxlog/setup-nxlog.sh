TMPDIR=${TMPDIR:-/tmp/}
NXLOG_ROOT=${NXLOG_ROOT:-~/.undeploy.me/nxlog}
NXLOG_MONITOR_DIR=${NXLOG_MONITOR_DIR:-~/.undeploy.me}
NXLOG_CONSUMER=${NXLOG_CONSUMER:-localhost}
NXLOG_RELEASE=${NXLOG_RELEASE:-stable}
NXLOG_REPO=${NXLOG_REPO:-http://qubell-logging.s3.amazonaws.com}
NXLOG_REGISTRY=${NXLOG_ROOT}/registry.txt

set -E

function detect_system # ()
{
  if [ -f /etc/redhat-release ]; then
    VER=$(cat /etc/redhat-release | sed -re 's/.*([0-9])\.[0-9].*/\1/g')
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
  curl -Lkso $TMPDIR/nxlog.tar.gz $NXLOG_REPO/$NXLOG_RELEASE/nxlog-static-$(detect_system).tar.gz
  tar xzvpf $TMPDIR/nxlog.tar.gz -C $NXLOG_ROOT --strip-components=1
}

function register_qubell_path # (group, logger_host, path)
{
  if [ "x$1" == "x--apply-now" ]; then
    POSTSCRIPT="apply_registry_changes; start_service"
    shift
  else
    POSTSCRIPT=true
  fi
  if ! grep "qubell $1 $2 $3" $NXLOG_REGISTRY 2>/dev/null 1>/dev/null; then
    echo "qubell $1 $2 $3" >> $NXLOG_REGISTRY
    eval "$POSTSCRIPT"
  fi
}

function register_user_path # (group, logger_host, path...)
{
  if [ "x$1" == "x--apply-now" ]; then
    POSTSCRIPT="apply_registry_changes; start_service"
    shift
  else
    POSTSCRIPT=true
  fi
  GROUP=$1
  HOST=$2
  shift 2
  while [ ! "x$1" == "x" ] && [ ! "x$1" == "x--" ]; do
    if ! grep "file $GROUP $HOST $1" $NXLOG_REGISTRY 2>/dev/null 1>/dev/null; then
      echo "file $GROUP $HOST $1" >> $NXLOG_REGISTRY
    fi
    shift
  done
  eval "$POSTSCRIPT"
}

function deregister_path # (group[, logger_host, [path...]])
{
  if [ "x$1" == "x--apply-now" ]; then
    POSTSCRIPT="apply_registry_changes; start_service"
    shift
  else
    POSTSCRIPT=true
  fi
  GROUP=$1
  HOST=$2
  shift; shift # sh does not changes $# if number is greater than arg count
  if [ "x$1" == "x" ] || [ "x$1" == "x--" ]; then
    /bin/cp -f $NXLOG_REGISTRY $NXLOG_REGISTRY~
    PATTERN=" $GROUP "
    echo "'$PATTERN'"
    if [ ! "x$HOST" == "x" ]; then
      PATTERN="$PATTERN$HOST "
    fi
    echo "'$PATTERN'"
    grep -v "$PATTERN" $NXLOG_REGISTRY~ > $NXLOG_REGISTRY
  else
    while [ ! "x$1" == "x" ] && [ ! "x$1" == "x--" ]; do
      /bin/cp -f $NXLOG_REGISTRY $NXLOG_REGISTRY~
      grep -v " $GROUP $HOST $1" $NXLOG_REGISTRY~ > $NXLOG_REGISTRY
      shift
    done
  fi
  eval "$POSTSCRIPT"
}

function show_registry
{
  cat $NXLOG_REGISTRY
}

function apply_registry_changes
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

    cat $NXLOG_REGISTRY | while read TARGET_TYPE GROUP LOGGER_HOST TARGET_PATH; do
      TARGET_ID=${GROUP}_$(head -c 100 /dev/urandom | base64 | sed 's/[+=/A-Z]//g' | tail -c 9)
      cat <<EOF

############################################################
# TYPE: $TARGET_TYPE    PATH: $TARGET_PATH    HOST: $LOGGER_HOST
############################################################

EOF
      case $TARGET_TYPE in
        qubell)
          TARGET_PREFIX_LEN=$(awk -v a="$TARGET_PATH" -v b=".undeploy.me" 'BEGIN{if (index(a, b)==0) {print length(a)} else {print index(a,b) + 12}}')
          cat <<EOF
<Input job_stdout_$TARGET_ID>
    Module im_file
    File "$TARGET_PATH/*.out"
    SavePos TRUE
    Recursive TRUE
    Exec \$Message = \$raw_event;
    Exec \$FileName = substr(file_name(), ${TARGET_PREFIX_LEN});
    Exec \$Stream = "stdout";
    Exec to_json();
</Input>

<Input job_stderr_$TARGET_ID>
    Module im_file
    File "$TARGET_PATH/*.err"
    SavePos TRUE
    Recursive TRUE
    Exec \$Message = \$raw_event;
    Exec \$FileName = substr(file_name(), ${TARGET_PREFIX_LEN});
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
    Exec \$FileName = file_name();
    Exec \$instId = "$GROUP";
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

function install # (consumer, monitor_dir, group)
{
  if [ -d $NXLOG_ROOT ]; then
    echo "NXLog already installed in $NXLOG_ROOT"
  else
    install_nxlog
  fi
  register_qubell_path ${3:-default} ${1:-$NXLOG_CONSUMER} ${2:-$NXLOG_MONITOR_DIR}
  apply_registry_changes
  start_service
}

### main
###

function help # ()
{
  cat <<EOF
  Usage:
    $0 COMMAND [ARGS ...] [-- COMMAND2 [ARGS ...] [-- COMMAND3 ...]]

    $0 install CONSUMER_HOST MONITOR_DIR GROUP
        Install, configure and start nxlog.

    $0 start_service
        Start installed service.

    $0 show_registry
    $0 register_qubell_path [--apply-now] GROUP LOGGER_HOST PATH
    $0 register_user_path [--apply-now] GROUP LOGGER_HOST PATH [PATH ...]
    $0 deregister_path [--apply-now] GROUP [LOGGER_HOST PATH [PATH ...]]
        View and edit list of logged entities.

        GROUP is any string without spaces, which can be used to identify
              related sets of paths. Inside one group, combinations
              LOGGER_HOST - PATH are unique, duplicates will be ignored.


    $0 apply_registry_changes
        Generates nxlog configuration from registry.

EOF
}

# no command provided
if [ "x$1" == "x" ]; then
  help
  exit 1
fi

while [ "x$1" != "x" ] && declare -F $1 2>&1 1>/dev/null ; do
  CMD="$1"
  shift
  $CMD "$@"
  while [ ! "x$1" == "x" ] && [ ! "x$1" == "x--" ]; do
    shift
  done
  shift
done

# unexpected command found
if [ ! "x$1" == "x" ]; then
  help
  exit 1
fi
