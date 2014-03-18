import os

from test_runner import BaseComponentTestCase
from qubell.api.private.testing import instance, environment, workflow, values


@environment({
    "default": {}
})
class ComponentTestCase(BaseComponentTestCase):
    name = "eggshell-white"
    apps = [{
        "name": name,
        "file": os.path.realpath(os.path.join(os.path.dirname(__file__), '../%s.yml' % name))
    }]

    def test_pass(self):
        assert True, "Just another test, that passes"
