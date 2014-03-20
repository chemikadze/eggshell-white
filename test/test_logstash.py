from datetime import datetime
import re

from elasticsearch import Elasticsearch, TransportError
import requests
from test_runner import BaseComponentTestCase, parameters as env_parameters
from qubell.api.private.testing import environment, instance, values


@environment({
    "default": {
        "policies": [{
            "action": "logging",
            "parameter": "version",
            "value": env_parameters['logger_version']
        }]
    }
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
        }
    },
    { "name": client_v1_name, "file": manifest(client_v1_name), "launch": False },
    { "name": client_v2_name, "file": manifest(client_v2_name), "launch": False }]

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

    @instance(byApplication=name)
    @values({"logger.logger-server": "logger_host"})
    def test_client_v1_can_connect(self, instance, logger_host):
        self._client_test_case(self.client_v1_name, instance, logger_host)

    @instance(byApplication=name)
    @values({"logger.logger-server": "logger_host"})
    def test_client_v2_can_connect(self, instance, logger_host):
        self._client_test_case(self.client_v2_name, instance, logger_host)

    def _client_test_case(self, client_name, instance, logger_host):
        environment = instance.environment
        instance.add_as_service(environments=[environment])
        client_app = self.organization.get_application(name=client_name)
        try:
            client_instance = client_app.launch(environment=environment)
            client_instance.ready(self.timeout())
            es = Elasticsearch([{'host': logger_host}])
            records = es.count(
                "logstash-" + datetime.utcnow().strftime('%Y.%m.%d.%H'),
                body={"query": {"term": {"instId": client_instance.id}}})
            self.assertTrue(records >= 2, "Expected at least two messages in index, got %s" % records)
        except TransportError as e:
            self.fail("Can not retrieve count of log messages: %s %s" % (e.status_code, e.error))
        finally:
            client_instance.destroy()
            client_instance.destroyed()


