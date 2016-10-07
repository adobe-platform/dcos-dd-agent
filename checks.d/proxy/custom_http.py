import time
import requests
import sys
import re

from checks import AgentCheck
from hashlib import md5

class HTTPCheck(AgentCheck):
    def check(self, instance):
        if 'url' not in instance:
            self.log.info("Skipping instance, no url found.")
            return

        # Load values from the instance config
        url = instance['url']
        tags = instance['tags']
        check_type = instance['type']
        default_timeout = self.init_config.get('default_timeout', 5)
        timeout = float(instance.get('timeout', default_timeout))

        # Use a hash of the URL as an aggregation key
        aggregation_key = md5(url).hexdigest()

        # Check the URL
        start_time = time.time()
        try:
            r = requests.get(url, timeout=timeout, verify=False)
            end_time = time.time()
        except requests.exceptions.Timeout as e:
            # If there's a timeout
            self.timeout_event(check_type, url, timeout, aggregation_key, tags)
            return
        except:
            e = sys.exc_info()[0]
            self.exception_event(check_type, url, e, aggregation_key, tags)

        if r.status_code >= 400:
            self.status_code_event_error(check_type, url, r, aggregation_key, tags)
        else:
            self.status_code_event(check_type, url, r, aggregation_key, tags)

        timing = end_time - start_time
        self.gauge('%s.response_time' % check_type, timing, tags=tags)
        self.gauge('%s.status_code' % check_type, r.status_code, tags=tags)

    def timeout_event(self, check_type, url, timeout, aggregation_key, tags):
        timestamp = int(time.time())

        # Mask the sensitive data on stream events
        url = re.sub("(?<=\/\/)(.*)(?=@)", "xxxxx:xxxxx", url)

        self.event({
            'timestamp': timestamp,
            'event_type': check_type,
            'msg_title': 'URL timeout',
            'msg_text': '%s timed out after %s seconds.' % (url, timeout),
            'aggregation_key': aggregation_key,
            'tags': tags,
            'alert_type': 'error'
        })

        self.service_check(check_name='%s.can_connect' % check_type, status=2, tags=tags,
                           timestamp=timestamp, message='%s timed out after %s seconds.' % (url, timeout))

    def status_code_event(self, check_type, url, r, aggregation_key, tags):
        timestamp = int(time.time())

        self.service_check(check_name='%s.can_connect' % check_type, status=0, tags=tags, timestamp=timestamp)

    def status_code_event_error(self, check_type, url, r, aggregation_key, tags):
        timestamp = int(time.time())

        # Mask the sensitive data on stream events
        url = re.sub("(?<=\/\/)(.*)(?=@)", "xxxxx:xxxxx", url)

        self.event({
            'timestamp': timestamp,
            'event_type': check_type,
            'msg_title': 'Invalid reponse code for %s' % url,
            'msg_text': '%s returned a status of %s' % (url, r.status_code),
            'aggregation_key': aggregation_key,
            'tags': tags,
            'alert_type': 'error'
        })

        self.service_check(check_name='%s.can_connect' % check_type, status=2, tags=tags,
                           timestamp=timestamp, message='%s returned a status of %s' % (url, r.status_code))

    def exception_event(self, check_type, url, e, aggregation_key, tags):
        timestamp = int(time.time())

        # Mask the sensitive data on stream events
        url = re.sub("(?<=\/\/)(.*)(?=@)", "xxxxx:xxxxx", url)

        self.event({
            'timestamp': timestamp,
            'event_type': check_type,
            'msg_title': 'Unknown error for %s' % url,
            'msg_text': '%s Exception %s' % (url, e),
            'aggregation_key': aggregation_key,
            'tags': tags,
            'alert_type': 'error'
        })

        self.service_check(check_name='%s.can_connect' % check_type, status=3, tags=tags,
                           timestamp=timestamp, message='%s Exception %s' % (url, e))

if __name__ == '__main__':
    check, instances = HTTPCheck.from_yaml('/etc/dd-agent/conf.d/custom_http.yaml')
    for instance in instances:
        print "\nRunning the check against url: %s" % (instance['url'])
        check.check(instance)
        if check.has_events():
            print 'Events: %s' % (check.get_events())
        print 'Metrics: %s' % (check.get_metrics())