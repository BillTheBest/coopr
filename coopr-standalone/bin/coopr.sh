#!/usr/bin/env bash

##############################################################################
##
##  Coopr Standalone start up script for *NIX and Mac
##
##############################################################################

# Server environment
# Add default JVM options here. You can also use JAVA_OPTS and COOPR_JAVA_OPTS to pass JVM options to this script.
export COOPR_JAVA_OPTS="-XX:+UseConcMarkSweepGC -Dderby.stream.error.field=DerbyUtil.DEV_NULL"

# UI environment
export ENVIRONMENT=local
export COOPR_NODE=${COOPR_NODE:-node}
export COOPR_NPM=${COOPR_NPM:-npm}
export COOPR_USE_NGUI=${COOPR_USE_NGUI:-false}
export COOPR_DISABLE_UI=${COOPR_DISABLE_UI:-false}

# Provisioner environment
export COOPR_RUBY=${COOPR_RUBY:-ruby}
export COOPR_USE_DUMMY_PROVISIONER=${COOPR_USE_DUMMY_PROVISIONER:-false}
export COOPR_API_USER=${COOPR_API_USER:-admin}
export COOPR_TENANT=${COOPR_TENANT:-superadmin}
export COOPR_NUM_WORKERS=${COOPR_NUM_WORKERS:-5}

APP_NAME="coopr-standalone"

program_is_installed ( ) { type ${1} >/dev/null 2>&1; }

warn ( ) { echo "WARN: ${*}"; }

die ( ) { echo ; echo "ERROR: ${*}" ; echo ; exit 1; }

# Attempt to set APP_HOME
# Resolve links: $0 may be a link
PRG=${0}
# Need this for relative symlinks.
while [ -h ${PRG} ]; do
    ls=`ls -ld ${PRG}`
    link=`expr ${ls} : '.*-> \(.*\)$'`
    if expr ${link} : '/.*' > /dev/null; then
        PRG=${link}
    else
        PRG=`dirname ${PRG}`/${link}
    fi
done
SAVED=`pwd`
cd `dirname ${PRG}`/.. >&-
APP_HOME=`pwd -P`

export PID_DIR=/var/tmp

# MAINDIR=$(cd $(dirname ${BASH_SOURCE[0]})/../.. && pwd)

export COOPR_HOME=${APP_HOME}
export COOPR_SERVER_HOME=${COOPR_HOME}/server
export COOPR_SERVER_CONF=${COOPR_HOME}/server/conf
export COOPR_PROVISIONER_CONF=${COOPR_HOME}/provisioner/master/conf
export PROVISIONER_SITE_CONF=${COOPR_PROVISIONER_CONF}/provisioner-site.xml
export COOPR_PROVISIONER_PLUGIN_DIR=${COOPR_HOME}/provisioner/worker/plugins
export COOPR_LOG_DIR=${COOPR_HOME}/logs
export COOPR_DATA_DIR=${COOPR_HOME}/data

# Add embedded bin PATH, if it exists
if [ -d ${COOPR_HOME}/embedded/bin ]; then
    export PATH=${COOPR_HOME}/embedded/bin:${PATH}
fi

# Create log dir
mkdir -p ${COOPR_LOG_DIR} || die "Could not create dir ${COOPR_LOG_DIR}: ${!}"

# Create data dir
mkdir -p ${COOPR_DATA_DIR} || die "Could not create dir ${COOPR_DATA_DIR}: ${!}"
SED_COOPR_DATA_DIR=`echo ${COOPR_DATA_DIR} | sed 's:/:\\\/:g'`
sed -i.old "s/COOPR_DATA_DIR/${SED_COOPR_DATA_DIR}/g" ${COOPR_SERVER_CONF}/coopr-site.xml
sed -i.old "s/COOPR_DATA_DIR/${SED_COOPR_DATA_DIR}/g" ${COOPR_PROVISIONER_CONF}/provisioner-site.xml

# Determine the Java command to use to start the JVM.
if [ -n "${JAVA_HOME}" ]; then
    if [ -x "${JAVA_HOME}/jre/sh/java" ]; then
        # IBM's JDK on AIX uses strange locations for the executables
        JAVACMD="${JAVA_HOME}/jre/sh/java"
    else
        JAVACMD="${JAVA_HOME}/bin/java"
    fi
    if [ ! -x "${JAVACMD}" ]; then
        die "JAVA_HOME is set to an invalid directory: ${JAVA_HOME}

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
    fi
else
    JAVACMD="java"
    which java >/dev/null 2>&1 || die "JAVA_HOME is not set and no 'java' command could be found in your PATH.

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
fi

# java version check
JAVA_VERSION=`java -version 2>&1 | grep "java version" | awk '{print $3}' | awk -F '.' '{print $2}'`
if [ ${JAVA_VERSION} -ne 6 ] && [ ${JAVA_VERSION} -ne 7 ]; then
  die "ERROR: Java version not supported
Please install Java 6 or 7 - other versions of Java are not yet supported."
fi

# Check node installation
program_is_installed node || die "Node.JS is not installed
Please install Node.JS - the minimum version supported v0.10.26."

# Check node version
NODE_VERSION=`node -v 2>&1`
NODE_VERSION_MINOR=`echo ${NODE_VERSION} | awk -F '.' '{print $2}'`
NODE_VERSION_PATCH=`echo ${NODE_VERSION} | awk -F '.' '{print $3}'`
if [ ${NODE_VERSION_MINOR} -lt 10 ]; then
  die "Node.JS version is not supported! The minimum version supported is v0.10.26."
elif [ ${NODE_VERSION_MINOR} -eq 10 ] && [ ${NODE_VERSION_PATCH} -lt 26 ]; then
  die "Node.JS version is not supported! The minimum version supported is v0.10.26."
fi

# Check ruby installation
program_is_installed ruby || die "Ruby not found! Please install Ruby - the minimum version supported v1.9.0p0"

# Check ruby version
RUBY_VERSION=`ruby -v 2>&1 | awk '{print $2}'`
RUBY_VERSION_MAJOR=`echo ${RUBY_VERSION} | awk -F '.' '{print $1}'`
RUBY_VERSION_MINOR=`echo ${RUBY_VERSION} | awk -F '.' '{print $2}'`
RUBY_VERSION_PATCH=`echo ${RUBY_VERSION} | awk -F '.' '{print $3}'`
if [ ${RUBY_VERSION_MAJOR} -lt 1 ]; then
  die "Ruby version is not supported! The minimum version supported is v1.9.0p0"
elif [ ${RUBY_VERSION_MAJOR} -eq 1 ] && [ ${RUBY_VERSION_MINOR} -lt 9 ]; then
  die "Ruby version is not supported! The minimum version supported is v1.9.0p0"
fi

# $1 - Property name to read
# $2 - Config file name to read from
# $3 - variable for return value
#
# Usage: read_property property_name /path/to/config/file variable_to_store_value
#
read_property () {
    property_re='(?<=<name>'$1'</name>)[\s\S]+?(?=</property>)'
    property_value_re='(?<=<value>)[\s\S]+?(?=</value>)'

    echo `grep -Pzoe $property_re $2 | grep -Pzoe $property_value_re`
}

# Setup coopr configuration
COOPR_PROTOCOL=http
COOPR_SSL=`read_property server.ssl.enabled ${COOPR_SERVER_CONF}coopr-site.xml`
if [ -z $COOPR_SSL ]; then
    COOPR_SSL="false"
fi
export COOPR_SSL
if [ $COOPR_SSL = "true" ]; then
    COOPR_PROTOCOL=https

    COOPR_NODEJS_SSL_PATH=`read_property server.nodejs.ssl.path ${COOPR_SERVER_CONF}coopr-security.xml`
    COOPR_NODEJS_SSL_KEY=`read_property server.nodejs.ssl.key ${COOPR_SERVER_CONF}coopr-security.xml`
    export COOPR_NODEJS_SSL_KEY=$COOPR_NODEJS_SSL_PATH"/"$COOPR_NODEJS_SSL_KEY
    COOPR_NODEJS_SSL_CRT=`read_property server.nodejs.ssl.crt ${COOPR_SERVER_CONF}coopr-security.xml`
    export COOPR_NODEJS_SSL_CRT=$COOPR_NODEJS_SSL_PATH"/"$COOPR_NODEJS_SSL_CRT
fi

export COOPR_SERVER_URI=${COOPR_PROTOCOL}://localhost:55054

read_property server.ssl.trust.cert.path ${COOPR_SERVER_CONF}coopr-security.xml TRUST_CERT_PATH
export TRUST_CERT_PATH

read_property server.ssl.trust.cert.password ${COOPR_SERVER_CONF}coopr-security.xml TRUST_CERT_PASSWORD
export TRUST_CERT_PASSWORD

if [ -n TRUST_CERT_PATH ] && [ -n TRUST_CERT_PASSWORD ]; then
  export CERT_PARAMETER="--cert ${TRUST_CERT_PATH}:${TRUST_CERT_PASSWORD}"
fi

if [ ${COOPR_PROTOCOL} = "https" ]; then
  export CURL_PARAMETER="--insecure"
  export COOPR_REJECT_UNAUTH=false
fi

read_property server.ssl.trust.keystore.path ${COOPR_SERVER_CONF}coopr-security.xml keystore_path
read_property server.ssl.trust.keystore.password ${COOPR_SERVER_CONF}coopr-security.xml keystore_password

COOPR_NODE_TLS_ENABLED="false"
if [ ! -z keystore_path ] && [ ! -z keystore_password ]; then
    COOPR_NODE_TLS_ENABLED="true"

    read_property server.nodejs.tls.cert.path ${COOPR_SERVER_CONF}coopr-security.xml nodejs_tls_path
    read_property server.nodejs.tls.key ${COOPR_SERVER_CONF}coopr-security.xml nodejs_tls_key
    read_property server.nodejs.tls.crt ${COOPR_SERVER_CONF}coopr-security.xml nodejs_tls_crt
    read_property server.nodejs.tls.ca ${COOPR_SERVER_CONF}coopr-security.xml nodejs_tls_ca
    read_property server.nodejs.tls.password ${COOPR_SERVER_CONF}coopr-security.xml COOPR_NODE_TLS_PASSWORD

    export COOPR_NODE_TLS_PASSWORD
    export COOPR_NODE_TLS_KEY=$nodejs_tls_path"/"$nodejs_tls_key
    export COOPR_NODE_TLS_CRT=$nodejs_tls_path"/"$nodejs_tls_crt
    export COOPR_NODE_TLS_CA=$nodejs_tls_path"/"$nodejs_tls_ca
fi
export COOPR_NODE_TLS_ENABLED

# Load default configuration
load_defaults () {
  shift;
  # We've already been loaded, do nothing and return 0
  [ -f ${COOPR_DATA_DIR}/.load_defaults ] && return 0

  echo "Waiting for server to start before loading default configuration..."
  wait_for_server

  echo "Loading default configuration..."
  $COOPR_HOME/server/templates/bin/load-templates.sh && touch ${COOPR_DATA_DIR}/.load_defaults

  # register the default plugins with the server
  provisioner register

  # load the initial plugin bundled data
  stage_default_data

  # sync the initial data to the provisioner
  sync_default_data

  # add some workers to the superadmin tenant
  request_superadmin_workers
}

stage_default_data () {
  echo "Waiting for plugins to be registered..."
  wait_for_plugin_registration

  cd ${COOPR_PROVISIONER_PLUGIN_DIR}
  echo "Loading initial data..."
  for script in $(ls -1 */*/load-bundled-data.sh) ; do
    ${COOPR_PROVISIONER_PLUGIN_DIR}/${script}
  done
}

sync_default_data () {
  echo "Syncing initial data..."
  curl ${CURL_PARAMETER} --silent --request POST \
    --header "Coopr-UserID:${COOPR_API_USER}" \
    --header "Coopr-TenantID:${COOPR_TENANT}" \
    --connect-timeout 5 \
    ${COOPR_SERVER_URI}/v2/plugins/sync
}

request_superadmin_workers () {
  [ "${COOPR_USE_DUMMY_PROVISIONER}" == "true" ] && sleep 5 || wait_for_provisioner

  echo "Requesting ${COOPR_NUM_WORKERS} workers for default tenant..."
  curl ${CURL_PARAMETER} --silent --request PUT \
    --header "Content-Type:application/json" \
    --header "Coopr-UserID:${COOPR_API_USER}" \
    --header "Coopr-TenantID:${COOPR_TENANT}" \
    --connect-timeout 5 --data "{ \"tenant\":{\"workers\":${COOPR_NUM_WORKERS}, \"name\":\"superadmin\"} }" \
    ${COOPR_SERVER_URI}/v2/tenants/superadmin
}

wait_for_server () {
  RETRIES=0
  until [[ $(curl ${CURL_PARAMETER} ${COOPR_SERVER_URI}/status 2> /dev/null | grep OK) || ${RETRIES} -gt 60 ]]; do
      sleep 2
      let "RETRIES++"
  done

  if [ ${RETRIES} -gt 60 ]; then
      die "Server did not successfully start"
  fi
}

wait_for_plugin_registration () {
  RETRIES=0
  until [[ $(curl ${CURL_PARAMETER} --silent --request GET \
    --output /dev/null --write-out "%{http_code}" \
    --header "Coopr-UserID:${COOPR_API_USER}" \
    --header "Coopr-TenantID:${COOPR_TENANT}" \
    ${COOPR_SERVER_URI}/v2/plugins/automatortypes/chef-solo 2> /dev/null) -eq 200 || ${RETRIES} -gt 60 ]]; do
    sleep 2
    let "RETRIES++"
  done

  if [ ${RETRIES} -gt 60 ]; then
    die "Provisioner did not successfully register plugins"
  fi
}

wait_for_provisioner () {
  RETRIES=0
  until [[ $(curl http://localhost:55056/status 2> /dev/null | grep OK) || ${RETRIES} -gt 60 ]]; do
    sleep 2
    let "RETRIES++"
  done

  if [ ${RETRIES} -gt 60 ]; then
    die "Provisioner did not successfully start"
  fi
}

provisioner () {
  if [ "$1" == "start" ]; then
    echo "Waiting for server to start before running provisioner..."
    wait_for_server
  fi
  if [ "${COOPR_USE_DUMMY_PROVISIONER}" == "true" ]; then
    ${COOPR_HOME}/server/templates/mock/load-mock.sh && \
    ${COOPR_HOME}/server/bin/dummy-provisioner.sh ${@}
  else
    ${COOPR_HOME}/provisioner/bin/provisioner.sh ${1}
  fi
}

server () { ${COOPR_HOME}/server/bin/server.sh ${1}; }

ui () {
  if [ "${COOPR_DISABLE_UI}" == "true" ]; then
    echo "UI disabled... skipping..."
    return 0
  fi
  if [ "${COOPR_USE_NGUI}" == "true" ]; then
    ${COOPR_HOME}/ngui/bin/ngui.sh ${1}
  else
    ${COOPR_HOME}/ui/bin/ui.sh ${1}
  fi
}

greeting () {
  [ "${COOPR_DISABLE_UI}" == "true" ] && return 0
  echo
  echo "Go to ${COOPR_PROTOCOL}://localhost:8100. Have fun creating clusters!"
}

stop () { provisioner stop; server stop; ui stop; }

start () { server start && ui start && provisioner start && load_defaults && greeting; }

# Main
case ${1} in
  start|stop) ${1} ;;
  restart) stop; start ;;
  status) for i in server ui provisioner ; do ${i} status ; done ;;
  *) echo "Usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac

exit $?
