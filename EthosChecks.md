# Ethos DD Agents Configuration

[datadog-control] Datadog agent for monitoring Mesos, Marathon &amp; ZooKeeper

```
docker run --name dd-agent-mesos-control \
-h `hostname` \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /proc/:/host/proc/:ro \
-v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
-e API_KEY=xxxx \
-e MESOS_HOST=localhost \
-e DD_TIER=control \
adobeplatform/ethos-dd-agent
```

[datadog-mesos-master] Datadog agent for monitoring Mesos masters

```
docker run --name dd-agent-mesos-master \
-h `hostname` \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /proc/:/host/proc/:ro \
-v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
-e API_KEY=xxxx \
-e HOST_IP=`hostname -i` \
-e MARATHON_USERNAME=username \
-e MARATHON_PASSWORD=password \
-e DD_TIER=master \
adobeplatform/ethos-dd-agent
```

[datadog-mesos-slave] Datadog agent for monitoring Mesos slaves

```
docker run --name dd-agent-mesos-slave \
-h `hostname` \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /proc/:/host/proc/:ro \
-v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
-e API_KEY=xxxx \
-e HOST_IP=`hostname -i` \
-e DD_TIER=slave \
adobeplatform/ethos-dd-agent
```

[datadog-proxy] Datadog agent for monitoring proxy nodes

```
docker run --name dd-agent-proxy \
---net='host' \
-e API_KEY=xxxx \
-e PROXY=localhost \
-e DD_TIER=proxy \
adobeplatform/ethos-dd-agent
```
