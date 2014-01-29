TMPDIR=${TMPDIR:-/tmp/}
NXLOG_ROOT=${NXLOG_DIR:-~/.undeploy.me/nxlog}
NXLOG_MONITOR_DIR=${NXLOG_DIR:-~/.undeploy.me}
NXLOG_CONSUMER=${NXLOG_CONSUMER:-localhost}
NXLOG_RELEASE=${NXLOG_RELEASE:-latest}
NXLOG_REPO=${NXLOG_REPO:-http://qubell-logging.s3.amazonaws.com/$NXLOG_RELEASE}

set -e

function detect_system # ()
{
  if [ -f /etc/redhat-release ]; then
    VER=$(cat /etc/redhat-release | sed -re 's/.*([0-9]\.[0-9]).*/\1/g')
    echo centos-$VER-$(uname -i)
  else
    echo "unsupported distro"
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

function configure_nxlog # (consumer, monitor_dir)
{
  NXLOG_CONSUMER_=${1}
  MONITORDIR_=$(readlink -f $2)
  cat > $NXLOG_ROOT/nxlog.conf <<EOF
########################################
# Generated automatically!             #
########################################
define ROOTDIR $NXLOG_ROOT
define MONITORDIR $MONITORDIR_

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

<Input job_stdout>
    Module im_file
    File "%MONITORDIR%/*.out"
    SavePos TRUE
    Recursive TRUE
    Exec \$Message = \$raw_event;
    Exec \$FileName = substr(file_name(), size("%MONITORDIR%")+1);
    Exec \$Stream = "stdout";
    Exec to_json();
</Input>

<Input job_stderr>
    Module im_file
    File "%MONITORDIR%/*.err"
    SavePos TRUE
    Recursive TRUE
    Exec \$Message = \$raw_event;
    Exec \$FileName = substr(file_name(), size("%MONITORDIR%")+1);
    Exec \$Stream = "stderr";
    Exec to_json();
</Input>

<Processor stderr_buffer>
    Module      pm_buffer
    # 8Mb buffer
    MaxSize 8192
    Type Mem
    # warn at 7M
    WarnLimit 7000
</Processor>


<Processor stdout_buffer>
    Module      pm_buffer
    # 8Mb buffer
    MaxSize 8192
    Type Mem
    # warn at 7M
    WarnLimit 7000
</Processor>

<Output log_ssl>
    Module  om_ssl
    Host    $NXLOG_CONSUMER_
    Port    8514
    AllowUntrusted TRUE
</Output>

<Route 1>
    Path    job_stdout => stdout_buffer => log_ssl
</Route>

<Route 2>
    Path    job_stderr => stderr_buffer => log_ssl
</Route>
EOF

}

function start_service # ()
{
  $NXLOG_ROOT/nxlog -c $NXLOG_ROOT/nxlog.conf
}

### main
###

if [ -d $NXLOG_ROOT ]; then
  echo "NXLog already installed in $NXLOG_ROOT"
else
  install_nxlog
  configure_nxlog ${1:-$NXLOG_CONSUMER} ${2:-$NXLOG_MONITOR_DIR}
  start_service
fi
