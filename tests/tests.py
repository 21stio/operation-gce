import sys
import unittest
import urllib.request

url = sys.argv[1]

def is_ingress_subdomain_routeable(subdomain):
    try:
        with urllib.request.urlopen("http://" + subdomain + "." + url) as response:
            body = response.read().decode('utf-8')

            if "404 page not found" in body:
                return False

    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False

    return True


class Test(unittest.TestCase):
    def test_ingress_echoheaders(self):
        self.assertTrue(is_ingress_subdomain_routeable("echoheaders"))

    def test_ingress_dashboard(self):
        self.assertTrue(is_ingress_subdomain_routeable("dashboard"))

    def test_ingress_traefik_ui(self):
        self.assertTrue(is_ingress_subdomain_routeable("traefik"))


suite = unittest.TestLoader().loadTestsFromTestCase(Test)
unittest.TextTestRunner(verbosity=3).run(suite)
