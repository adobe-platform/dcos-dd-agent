FROM datadog/docker-dd-agent:11.2.584

MAINTAINER Ethos DevOPS <Ethos_Dev@adobe.com>

# Add the entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Extra conf.d and checks.d
CMD mkdir -p /conf.d
CMD mkdir -p /checks.d
VOLUME ["/conf.d"]
VOLUME ["/checks.d"]

# Add ethos checks
ADD checks.d/ /checks.d/
ADD conf.d/ /conf.d/

# Expose DogStatsD port
EXPOSE 8125/udp

ENTRYPOINT ["/entrypoint.sh"]
CMD ["supervisord", "-n", "-c", "/etc/dd-agent/supervisor.conf"]
