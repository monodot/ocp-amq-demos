#!/bin/sh

. $AMQ_HOME/bin/configure.sh
. $AMQ_HOME/bin/partitionPV.sh
. /usr/local/dynamic-resources/dynamic_resources.sh

ACTIVEMQ_OPTS="-javaagent:${AMQ_HOME}/jolokia.jar=port=8778,protocol=https,caCert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt,clientPrincipal=cn=system:master-proxy,extraClientCheck=true,host=0.0.0.0,discoveryEnabled=false,user=user,password=password,authMode=basic"
ACTIVEMQ_OPTS="${ACTIVEMQ_OPTS} -XX:+DisableAttachMechanism -Dorg.apache.activemq.audit=true -Dcom.sun.management.jmxremote.port=1099 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.login.config=LdapJmxConfiguration -Djava.security.auth.login.config=${AMQ_HOME}/conf/login.config -Dcom.sun.management.jmxremote.access.file=${AMQ_HOME}/conf/jmx.access"
ACTIVEMQ_OPTS="${ACTIVEMQ_OPTS} -javaagent:${AMQ_HOME}/lib/byteman.jar=script:${AMQ_HOME}/conf/rules.btm,boot:${AMQ_HOME}/lib/byteman.jar -Dorg.jboss.byteman.verbose=true -Dorg.apache.activemq.audit=true"

MAX_HEAP=`get_heap_size`
if [ -n "$MAX_HEAP" ]; then
  ACTIVEMQ_OPTS="-Xms${MAX_HEAP}m -Xmx${MAX_HEAP}m $ACTIVEMQ_OPTS"
fi

# Make sure that we use /dev/urandom
ACTIVEMQ_OPTS="${ACTIVEMQ_OPTS} -Djava.security.egd=file:/dev/./urandom"

# Add jolokia command line options
cat <<EOF > $AMQ_HOME/bin/env
ACTIVEMQ_OPTS="${ACTIVEMQ_OPTS}"
EOF

echo "Running $JBOSS_IMAGE_NAME image, version $JBOSS_IMAGE_VERSION-$JBOSS_IMAGE_RELEASE"

# Parameters are
# - instance directory
function runServer() {
  # Fix log file
  local instanceDir=$1
  local log_file="$AMQ_HOME/conf/log4j.properties"
  sed -i "s+activemq\.base}/data+activemq.data}+" "$log_file"

  export ACTIVEMQ_DATA="$instanceDir"
  exec "$AMQ_HOME/bin/activemq" console
}

if [ "$AMQ_SPLIT" = "true" ]; then
  DATA_DIR="${AMQ_HOME}/data"
  mkdir -p "${DATA_DIR}"

  partitionPV "${DATA_DIR}" "${AMQ_LOCK_TIMEOUT:-30}"
else
    exec $AMQ_HOME/bin/activemq console
fi