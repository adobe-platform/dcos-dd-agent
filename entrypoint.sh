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
# CAPCOM_PORT
# DD_TIER
# ETCD_HOST
# ETCD_PORT
# FLIGHT_DIRECTOR_URL
# HOST_IP
# LOG_LEVEL
# MARATHON_PORT
# MARATHON_USERNAME
# MARATHON_PASSWORD
# MESOS_HOST
# MESOS_PROTOCOL
# MESOS_PORT
# PROJECT_ID
# PROXY
# RDS_FD_INSTANCE
# RDS_FD_USERNAME
# RDS_FD_PASSWORD 
# FD_HOST
# FD_PORT
# REGION_SHORTNAME
# STACK_NAME
# TAGS
# ZK_USERNAME
# ZK_PASSWORD
# EXTERNAL_CHECK_NODES

#fetch tags for instance

# Ensure STACK_NAME and PROJECT_ID is set
if [[ -z $STACK_NAME ]]; then
    echo "You must set STACK_NAME environment variable to run the Datadog Agent container"
    exit 1
else
   PROJECT_ID=$(echo $STACK_NAME | awk -F "-" '{print $1"-"$2}')
   
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

if [[ -z $ETCD_HOST ]]; then
    echo "ETCD HOST environment variable not provided, defaulting to etcd-server.etcd.mesos..."
    MESOS_HOST="etcd-server.etcd.mesos"
fi

if [[ -z $ETCD_PORT ]]; then
    echo "ETCD PORT environment variable not provided, defaulting to 1026..."
    MESOS_PORT="1026"
fi

echo "Using MESOS_HOST: $MESOS_HOST"

if [[ -z $MESOS_PROTOCOL ]]; then
    echo "MESOS_PROTOCOL environment variable not provided, defaulting to http..."
    MESOS_PROTOCOL="http"
fi

if [[ -z $FD_HOST ]]; then
echo "ETCD HOST environment variable not provided, defaulting to etcd-server.etcd.mesos..."
FD_HOST="flight-director.marathon.mesos"
fi

if [[ -z $FD_PORT ]]; then
echo "ETCD PORT environment variable not provided, defaulting to 1026..."
FD_PORT="2001"
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

    # configure external checks
    # check which nodes enables external checks
    if [[ -z $EXTERNAL_CHECK_NODES ]]; then
	# if not set turn on all control nodes by default
        EXTERNAL_CHECK_NODES=$HOST_IP
    fi
    # mesos master checks
    for i in $EXTERNAL_CHECK_NODES; do
	# only setup external checks on specified hosts
	if [[ "$(/usr/bin/dig +short ${i})" == "$(/usr/bin/dig +short ${HOST_IP})" ]]; then
    		sed -i -e "s/MESOS_PORT/${MESOS_PORT}/" /etc/dd-agent/conf.d/mesos_master.yaml
    		sed -i -e "s/MESOS_HOST/${MESOS_HOST}/" /etc/dd-agent/conf.d/mesos_master.yaml
    		sed -i -e "s/MESOS_PROTOCOL/${MESOS_PROTOCOL}/" /etc/dd-agent/conf.d/mesos_master.yaml
    		#marathon checks
    		sed -i -e "s/MARATHON_PORT/${MARATHON_PORT}/" /etc/dd-agent/conf.d/marathon.yaml
    		sed -i -e "s/MESOS_HOST/${MESOS_HOST}/" /etc/dd-agent/conf.d/marathon.yaml
    		sed -i -e "s/MESOS_PROTOCOL/${MESOS_PROTOCOL}/" /etc/dd-agent/conf.d/marathon.yaml
    		if [[ $MARATHON_PASSWORD && $MARATHON_USERNAME ]]; then
    		    sed -i -e "s/#  user:MARATHON_USERNAME/  user: ${MARATHON_USERNAME}/" /etc/dd-agent/conf.d/marathon.yaml
    		    sed -i -e "s/#  user:MARATHON_PASSWORD/  password: ${MARATHON_USERNAME}/" /etc/dd-agent/conf.d/marathon.yaml
    		fi
    		#etcd checks
    		sed -i -e "s/ETCD_HOST/${ETCD_HOST}/" /etc/dd-agent/conf.d/etcd.yaml
    		sed -i -e "s/ETCD_PORT/${ETCD_PORT}/" /etc/dd-agent/conf.d/etcd.yaml
    		#flight-director checks
    		sed -i -e "s/FD_HOST/${FD_HOST}/" /etc/dd-agent/conf.d/custom_http.yaml
    		sed -i -e "s/FD_PORT/${FD_PORT}/" /etc/dd-agent/conf.d/custom_http.yaml
    		#zookeeper check
    		sed -i -e "s/MESOS_HOST/${MESOS_HOST}/" /etc/dd-agent/conf.d/zk.yaml
	fi
    done

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
elif [[ $DD_TIER == "public" ]]; then
    echo "Configuring public tier"
else
    echo "Invalid DD tier value."
    exit 1
fi
	
#fluentd check runs on all agents
REMOVE_CHECK=true
for i in $(/usr/bin/dig +short fluentd.marathon.mesos A | /usr/bin/tr "\n" " "); do
	if [[ "$i" == "$(dig +short ${HOST_IP})" ]]; then	
		echo "fluentd present: adding check"
		sed -i -e "s/HOST_IP/${HOST_IP}/" /etc/dd-agent/conf.d/fluentd.yaml	
		REMOVE_CHECK=false
	fi
done
if $REMOVE_CHECK; then
	rm -rf /etc/dd-agent/conf.d/fluentd.yaml	
	REMOVE_CHECK=true
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


if [[ -z $TAGS ]]; then
	TAGS="project_id:${PROJECT_ID}, stack_name:${STACK_NAME}, role:${DD_TIER}"
	sed -i -e "s/^#tags:.*$/tags: ${TAGS}/" /etc/dd-agent/datadog.conf
else
	TAGS="project_id:${PROJECT_ID}, stack_name:${STACK_NAME}, role:${DD_TIER}, ${TAGS}"
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
