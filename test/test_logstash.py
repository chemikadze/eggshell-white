from datetime import datetime
import re

from elasticsearch import Elasticsearch, TransportError
import requests
from test_runner import BaseComponentTestCase, parameters as env_parameters
from qubell.api.private.testing import environment, instance, values

def make_env(image, identity, group=None):
    return {"policies": [
        {"action": "provisionVms", "parameter": "imageId", "value": image},
        {"action": "provisionVms", "parameter": "vmIdentity", "value": identity},
        {"action": ".install-logger", "parameter": "vm-user", "value": identity},
        {"action": ".install-logger", "parameter": "vm-group", "value": group or identity},
        {"action": "loggingSettings", "parameter": "version", "value": env_parameters['logger_version']},
        {"action": "provisionVms", "parameter": "retryCount", "value": "3"}]
    }

@environment({
    "default": {"policies": [
        {"action": "loggingSettings", "parameter": "version", "value": env_parameters['logger_version']}]
    },
    # https://www.ruby-forum.com/topic/519162
    # "AmazonEC2_CentOS_53_i686":     make_env("us-east-1/ami-beda31d7", "root"),
    # "AmazonEC2_CentOS_58_x86_64":   make_env("us-east-1/ami-ed9c1084", "root"),
    "AmazonEC2_CentOS_63_i686":     make_env("us-east-1/ami-856a00ec", "root"),
    "AmazonEC2_CentOS_63_x86_64":   make_env("us-east-1/ami-eb6b0182", "root"),
    "AmazonEC2_Ubuntu_1004_i686":   make_env("us-east-1/ami-fb3c0392", "ubuntu"),
    "AmazonEC2_Ubuntu_1004_x86_64": make_env("us-east-1/ami-9f3906f6", "ubuntu"),
    "AmazonEC2_Ubuntu_1204_i686":   make_env("us-east-1/ami-a18c8fc8", "ubuntu"),
    "AmazonEC2_Ubuntu_1204_x86_64": make_env("us-east-1/ami-6f969506", "ubuntu"),
    "AmazonEC2_Ubuntu_1404_x86_64": make_env("us-east-1/ami-7fe7fe16", "ubuntu"),
    "AmazonLinux_2013.09_x86_64":   make_env("us-east-1/ami-1ba18d72", "ec2-user")
})
class ComponentTestCase(BaseComponentTestCase):
    manifest = BaseComponentTestCase.manifest
    name = "logstash"
    client_v1_name = "nxlog-example"
    client_v2_name = "nxlog-example.v2"
    apps = [{
        "name": name,
        "file": manifest(name),
        "parameters": {
            "configuration.logging-cookbooks-version": env_parameters['logger_version']
        },
        "add_as_service": True
    },
    { "name": client_v1_name, "file": manifest(client_v1_name)},
    { "name": client_v2_name, "file": manifest(client_v2_name)}]

    ip_pattern = "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"
    url_re = re.compile(
        r'^https?://'
        r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+(?:[A-Z]{2,6}\.?|[A-Z0-9-]{2,}\.?)|'
        r'localhost|'
        r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
        r'(?::\d+)?'
        r'(?:/?|[/?]\S+)$', re.IGNORECASE)

    @classmethod
    def timeout(cls):
        return 20;

    @instance(byApplication=name)
    @values({"logger.logger-server": "logger_host"})
    def test_return_logger_ip(self, instance, logger_host):
        self.assertIsNotNone(re.match(self.ip_pattern, logger_host),
            "logger-server should be a valid IP")

    @instance(byApplication=name)
    @values({"logger.kibana-dashboard": "kibana_url"})
    def test_return_kibana_url(self, instance, kibana_url):
        self.assertIsNotNone(self.url_re.match(kibana_url), "kibana-url should be a valid url")

    @instance(byApplication=name)
    @values({"logger.kibana-dashboard": "kibana_url"})
    def test_kibana_is_available(self, instance, kibana_url):
        resp = requests.get(kibana_url, verify=False)
        self.assertEqual(resp.status_code, 200)

    @instance(byApplication=name)
    @values({"logger.logger-server": "logger_host"})
    def test_elasticsearch_is_available(self, instance, logger_host):
        resp = requests.get("http://%s:9200" % logger_host)
        data = resp.json()
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(data['status'], 200)
        self.assertTrue(data['ok'])

    @instance(byApplication=client_v1_name)
    def test_client_v1_can_connect(self, instance):
        self._client_test_case(instance)

    @instance(byApplication=client_v2_name)
    def test_client_v2_can_connect(self, instance):
        self._client_test_case(instance)

    def _client_test_case(self, instance):
        try:
            loggers = [inst for inst in instance.environment.services if instance.organization.application(inst.applicationId).name == self.name]
            host = loggers[0].returnValues["logger.logger-server"]
            es = Elasticsearch([{'host': host}])
            index_name = "logstash-" + datetime.utcnow().strftime('%Y.%m.%d')
            records_count = es.count(
                index_name,
                body={"query": {"term": {"instId": instance.id}}})
            self.assertTrue(records_count >= 2, "Expected at least two messages in index, got %s" % records_count)
            records = es.search(index=index_name, body={"query": {"match_all": {}}})['hits']['hits']
            for record in records:
                self.assertEqual(record['_source']['@message'], 'Hello from execrun!')
                expected_keys = ['@severity', '@timestamp', 'filename', 'instId', 'jobId', 'stepId', 'stepname', 'host', '@message']
                for key in expected_keys:
                    self.assertIn(key, record['_source'], "Message saved to elasticsearch should contain field %s" % key)
        except TransportError as e:
            self.fail("Can not retrieve count of log messages: %s %s" % (e.status_code, e.error))


