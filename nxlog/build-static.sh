set -e

ROOT=$(pwd)
NXLOG_VERSION=2.5.1089
# NXLOG_SRC="http://downloads.sourceforge.net/project/nxlog-ce/nxlog-ce-$NXLOG_VERSION.tar.gz"
NXLOG_SRC="https://s3.amazonaws.com/qubell-logging/nxlog-ce-$NXLOG_VERSION.tar.gz"

APR_VERSION=1.4.8
APR_SRC="http://archive.apache.org/dist/apr/apr-$APR_VERSION.tar.gz"

PCRE_VERSION=8.33
PCRE_SRC="http://downloads.sourceforge.net/project/pcre/pcre/$PCRE_VERSION/pcre-$PCRE_VERSION.tar.gz"

OPENSSL_VERSION=1.0.1e
OPENSSL_SRC="http://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"

EXPAT_VERSION=2.1.0
EXPAT_SRC="http://downloads.sourceforge.net/project/expat/expat/$EXPAT_VERSION/expat-$EXPAT_VERSION.tar.gz"

ZLIB_VERSION=1.2.8
ZLIB_SRC="http://downloads.sourceforge.net/project/libpng/zlib/$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.gz"

BUILD_DIR=build
OUTPUT_DIR=nxlog-static-$NXLOG_VERSION

mkdir -p $BUILD_DIR

function detect_system # ()
{
  ARCH=$(uname -m)
  if [ -f /etc/redhat-release ]; then # redhat/centos
    VER=$(cat /etc/redhat-release | sed -re 's/.*([0-9])\.[0-9].*/\1/g')
    echo centos-$VER-$ARCH
  elif [ -f /etc/debian_version ] && [ -f /etc/os-release ]; then # ubuntu
    (
      source /etc/os-release
      if [ -n $ID ] && [ -n $VERSION_ID ]; then
        echo $ID-$VERSION_ID-$ARCH | tr '[A-Z]' '[a-z]'
      fi
    )
  elif which lsb_release 2>/dev/null 1>/dev/null; then
    echo $(lsb_release -si)-$(lsb_release -sr)-$ARCH | tr '[A-Z]' '[a-z]'
  else
    echo unknown-1.0-$ARCH
  fi
}

pushd $BUILD_DIR

if [ "x$1" == "xfull" ]; then

(
  wget "$APR_SRC"
  tar xzvpf apr-$APR_VERSION.tar.gz
  cd  apr-$APR_VERSION
  CFLAGS="-fPIC" ./configure --disable-shared --enable-static --with-pic
  make clean
  make # ./.libs/libapr-1.a
  cp .libs/*.a .
)

(
  wget "$PCRE_SRC"
  tar xzvpf pcre-$PCRE_VERSION.tar.gz
  cd  pcre-$PCRE_VERSION
  ./configure --disable-shared --enable-static --with-pic --disable-cpp --includedir=$PWD --libdir=$PWD/.libs
  make clean
  make # ./.libs/libpcre.a
  cp .libs/*.a .
)

(
  wget "$ZLIB_SRC"
  tar xzvpf zlib-$ZLIB_VERSION.tar.gz
  cd zlib-$ZLIB_VERSION
  CFLAGS=-fPIC ./configure --static
  make clean
  make
)

(
  wget "$OPENSSL_SRC"
  tar xzvpf openssl-$OPENSSL_VERSION.tar.gz
  cd openssl-$OPENSSL_VERSION

  ./config no-shared zlib no-krb5 -fPIC -I$ROOT/build/zlib-$ZLIB_VERSION -L$ROOT/build/zlib-$ZLIB_VERSION -lz
  make clean
  make
)

(
  wget "$EXPAT_SRC"
  tar xzvpf expat-$EXPAT_VERSION.tar.gz
  cd expat-$EXPAT_VERSION
  CFLAGS=-fPIC ./configure --disable-shared --enable-static
  make clean
  make
)

fi

(

  wget "$NXLOG_SRC"
  tar xzvpf nxlog-ce-$NXLOG_VERSION.tar.gz
  cd nxlog-ce-$NXLOG_VERSION

  patch -p0 <<EOF
--- nxlog-ce-2.5.1089/configure 2013-07-04 21:08:57.000000000 +0900
+++ configure 2014-01-31 04:53:06.000000000 +0900
@@ -11322,2 +11322,4 @@
 PCRE_CFLAGS=\`\$pcre_config --cflags\`
+LIBS="\$PCRE_LIBS \$LIBS"
+CFLAGS="\$PCRE_CFLAGS \$CFLAGS"

@@ -11928,3 +11930,3 @@
   cat >>confdefs.h <<_ACEOF
-#define HAVE_SYS_PRCTL_H 1
+#define HAVE_SYS_PRCTL_H_HIDDEN 1
 _ACEOF
EOF
  cp configure configure.orig
  cat configure.orig | sed -re 's/for ac_func in prctl setpflags/for ac_func in fake/' > configure

  export PATH=$ROOT/build/apr-$APR_VERSION:$ROOT/build/pcre-$PCRE_VERSION:$PATH
  export CFLAGS="-I$ROOT/build/openssl-$OPENSSL_VERSION/include -I$ROOT/build/zlib-$ZLIB_VERSION -I$ROOT/build/expat-$EXPAT_VERSION/lib"
  export LDFLAGS="-L$ROOT/build/openssl-$OPENSSL_VERSION -L$ROOT/build/zlib-$ZLIB_VERSION -L$ROOT/build/expat-$EXPAT_VERSION/.libs"
  export LIBS="-lssl -lcrypto -lz"
  ./configure --disable-xm_perl
  make clean
  make

  mkdir -p $OUTPUT_DIR
  /bin/cp -vf src/core/nxlog $OUTPUT_DIR
  for i in input output processor extension; do
    mkdir -p $OUTPUT_DIR/$i
    /bin/cp -vf src/modules/$i/*.so $OUTPUT_DIR/$i/
  done

  tar czvpf $OUTPUT_DIR.tar.gz $OUTPUT_DIR
)

popd # build

cp $BUILD_DIR/nxlog-ce-$NXLOG_VERSION/$OUTPUT_DIR.tar.gz nxlog-static-$(detect_system).tar.gz
