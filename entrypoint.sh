#!/bin/bash
#set -e

echo "Initiating Datadog..."

if [[ $API_KEY ]]; then
	sed -i -e "s/^.*api_key:.*$/api_key: ${API_KEY}/" /etc/dd-agent/datadog.conf
else
	echo "You must set API_KEY environment variable to run the Datadog Agent container"
	exit 1
fi

#################################### ETHOS LOGIC ####################################

# Environment Variables:
# API_KEY
# DD_TIER
# HOST_IP
# REGION_SHORTNAME
# MESOS_HOST
# MESOS_PROTOCOL
# RDS_FD_INSTANCE
# RDS_FD_USERNAME
# RDS_FD_PASSWORD
# PROXY
# CAPCOM_PORT
# STACK_NAME
# MARATHON_USERNAME
# MARATHON_PASSWORD
# ZK_USERNAME
# ZK_PASSWORD
# PROJECT_ID
# TAGS
# LOG_LEVEL

# Ensure STACK_NAME and PROJECT_ID is set
if [[ -z $STACK_NAME ]]; then
    echo "You must set STACK_NAME environment variable to run the Datadog Agent container"
    exit 1
fi

if [[ -z $PROJECT_ID ]]; then
    echo "You must set PROJECT_ID environment variable to run the Datadog Agent container"
    exit 1
fi

# Determine current Ethos role:
if [[ -z $DD_TIER ]]; then
    echo "DD_TIER environment variable not provided. Obtaining via Mesos attributes..."
    DD_TIER=$(grep -ioP "ethos_role:\K\w+" /var/lib/dcos/mesos-slave-common)

    if [[ -z $DD_TIER ]]; then
        echo "Unable to determine DD_TIER. Ensure /var/lib/dcos/mesos-slave-common is set."
        exit 1
    fi
fi

echo "Using DD_TIER: $DD_TIER"

# Determine host IP
if [[ -z $HOST_IP ]]; then
    echo "HOST_IP environment variable not provided. Obtaining..."
    #HOST_IP=$(/sbin/ip route|awk '/default/ { print $9 }')
    HOST_IP=$(/bin/cat /etc/hostname)

    if [[ -z $HOST_IP ]]; then
        echo "Could not determine the host IP address."
        exit 1
    fi    
fi

echo "Using HOST_IP: $HOST_IP"

# Determine region shortname
if [[ -z $REGION_SHORTNAME ]]; then
    echo "REGION_SHORTNAME environment variable not provided. Defaulting to na..."
    REGION_SHORTNAME="na"
fi

echo "Using REGION_SHORTNAME: $REGION_SHORTNAME"

# Determine Capcom Port
if [[ -z $CAPCOM_PORT ]]; then
    echo "CAPCOM_PORT environment variable not provided. Defaulting to 2002..."
    CAPCOM_PORT="2002"
fi

echo "Using CAPCOM_PORT: $CAPCOM_PORT"

# Determine the Mesos Host
if [[ -z $MESOS_HOST ]]; then
    echo "MESOS_HOST environment variable not provided, defaulting to leader.mesos..."
    MESOS_HOST="leader.mesos"
fi

echo "Using MESOS_HOST: $MESOS_HOST"

if [[ -z $MESOS_PROTOCOL ]]; then
    echo "MESOS_PROTOCOL environment variable not provided, defaulting to http..."
    MESOS_PROTOCOL="http"
fi

echo "Using MESOS_PROTOCOL: $MESOS_PROTOCOL"

# copy the relevant tier checks
echo "Copying checks for tier"
cp -R /conf.d/${DD_TIER}/* /etc/dd-agent/conf.d/
cp -R /checks.d/${DD_TIER}/* /etc/dd-agent/checks.d/
cp -R /conf.d/shared/* /etc/dd-agent/conf.d/
cp -R /checks.d/shared/* /etc/dd-agent/checks.d/

# configure the checks
if [[ $DD_TIER == "control" ]]; then
    echo "Configuring control tier"

    if [[ $RDS_FD_INSTANCE && $RDS_FD_USERNAME && $RDS_FD_PASSWORD ]]; then
        sed -i -e "s/RDS_FD_INSTANCE/${RDS_FD_INSTANCE}/" /etc/dd-agent/conf.d/mysql.yaml
        sed -i -e "s/RDS_FD_USERNAME/${RDS_FD_USERNAME}/" /etc/dd-agent/conf.d/mysql.yaml
        sed -i -e "s/RDS_FD_PASSWORD/${RDS_FD_PASSWORD}/" /etc/dd-agent/conf.d/mysql.yaml
        sed -i -e "s/REGION_SHORTNAME/-${REGION_SHORTNAME}/" /etc/dd-agent/conf.d/mysql.yaml
    else
        # No MySQL DB to monitor
        echo "" > /etc/dd-agent/conf.d/mysql.yaml
    fi

elif [[ $DD_TIER == "worker" ]]; then
    echo "Configuring worker tier"

elif [[ $DD_TIER == "proxy" ]]; then
    echo "Configuring proxy tier"

    if [[ $PROXY ]]; then
        rm -Rf /etc/dd-agent/conf.d/sw/
        cp /conf.d/${DD_TIER}/sw/${PROXY}.yaml /etc/dd-agent/conf.d/.
    else
        echo 'No $PROXY environment variable detected. Must either be haproxy or nginx'
        exit 1
    fi

    sed -i -e "s/CAPCOM_HOST/${HOST_IP}/" /etc/dd-agent/conf.d/custom_http.yaml
    sed -i -e "s/CAPCOM_PORT/${CAPCOM_PORT}/" /etc/dd-agent/conf.d/custom_http.yaml
else
    echo "Invalid DD tier value."
    exit 1
fi

# Shared configs
sed -i -e "s/HOST_IP/${HOST_IP}/" /etc/dd-agent/conf.d/shared_http.yaml
sed -i -e "s/MESOS_HOST/${MESOS_HOST}/" /etc/dd-agent/conf.d/shared_http.yaml
sed -i -e "s/MESOS_PROTOCOL/${MESOS_PROTOCOL}/" /etc/dd-agent/conf.d/shared_http.yaml
sed -i -e "s/MESOS_PROTOCOL/${MESOS_PROTOCOL}/" /etc/dd-agent/conf.d/custom_http.yaml
sed -i -e "s/HOST_IP/${HOST_IP}/" /etc/dd-agent/conf.d/custom_http.yaml

sed -i -e "s/STACK_NAME/${STACK_NAME}/" /etc/dd-agent/conf.d/shared_http.yaml
sed -i -e "s/STACK_NAME/${STACK_NAME}/" /etc/dd-agent/conf.d/custom_http.yaml
sed -i -e "s/PROJECT_ID/${PROJECT_ID}/" /etc/dd-agent/conf.d/shared_http.yaml
sed -i -e "s/PROJECT_ID/${PROJECT_ID}/" /etc/dd-agent/conf.d/custom_http.yaml

if [[ $MARATHON_USERNAME && $MARATHON_PASSWORD ]]; then
    sed -i -e "s/MARATHON_AUTH/${MARATHON_USERNAME}:${MARATHON_PASSWORD}@/" /etc/dd-agent/conf.d/shared_http.yaml
else
    sed -i -e "s/MARATHON_AUTH//" /etc/dd-agent/conf.d/shared_http.yaml
fi

if [[ $ZK_USERNAME && $ZK_PASSWORD ]]; then
    sed -i -e "s/ZK_AUTH/${ZK_USERNAME}:${ZK_PASSWORD}@/" /etc/dd-agent/conf.d/shared_http.yaml
else
    sed -i -e "s/ZK_AUTH//" /etc/dd-agent/conf.d/shared_http.yaml
fi

#####################################################################################


if [[ $TAGS ]]; then
	sed -i -e "s/^#tags:.*$/tags: ${TAGS}/" /etc/dd-agent/datadog.conf
fi

if [[ $LOG_LEVEL ]]; then
    sed -i -e"s/^.*log_level:.*$/log_level: ${LOG_LEVEL}/" /etc/dd-agent/datadog.conf
fi

if [[ $DD_URL ]]; then
    sed -i -e 's@^.*dd_url:.*$@dd_url: '${DD_URL}'@' /etc/dd-agent/datadog.conf
fi

if [[ $PROXY_HOST ]]; then
    sed -i -e "s/^# proxy_host:.*$/proxy_host: ${PROXY_HOST}/" /etc/dd-agent/datadog.conf
fi

if [[ $PROXY_PORT ]]; then
    sed -i -e "s/^# proxy_port:.*$/proxy_port: ${PROXY_PORT}/" /etc/dd-agent/datadog.conf
fi

if [[ $PROXY_USER ]]; then
    sed -i -e "s/^# proxy_user:.*$/proxy_user: ${PROXY_USER}/" /etc/dd-agent/datadog.conf
fi

if [[ $PROXY_PASSWORD ]]; then
    sed -i -e "s/^# proxy_password:.*$/proxy_password: ${PROXY_USER}/" /etc/dd-agent/datadog.conf
fi

if [[ $STATSD_METRIC_NAMESPACE ]]; then
    sed -i -e "s/^# statsd_metric_namespace:.*$/statsd_metric_namespace: ${STATSD_METRIC_NAMESPACE}/" /etc/dd-agent/datadog.conf
fi

export PATH="/opt/datadog-agent/embedded/bin:/opt/datadog-agent/bin:$PATH"

if [[ $DOGSTATSD_ONLY ]]; then
		PYTHONPATH=/opt/datadog-agent/agent /opt/datadog-agent/embedded/bin/python /opt/datadog-agent/agent/dogstatsd.py
else
		exec "$@"
fi
