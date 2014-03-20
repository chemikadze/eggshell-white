import os
import re

import requests
from test_runner import BaseComponentTestCase, parameters as env_parameters
from qubell.api.private.testing import environment, instance, values


@environment({
    "default": {}
})
class ComponentTestCase(BaseComponentTestCase):
    name = "logstash"
    apps = [{
        "name": name,
        "file": os.path.realpath(os.path.join(os.path.dirname(__file__), '../manifests/%s.yaml' % name)),
        "parameters": {
            "configuration.logging-cookbooks-version": env_parameters['logger_version']
        }
    }]

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
