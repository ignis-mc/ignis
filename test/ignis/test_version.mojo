from ignis.version import DRAGONFLY_VERSION, GAME_VERSION, PROTOCOL
from std.testing import TestSuite, assert_equal


def test_versions_match_the_protocol_port() raises:
    assert_equal(PROTOCOL, 2225)
    assert_equal(String(GAME_VERSION), "1.26.60")
    assert_equal(String(DRAGONFLY_VERSION), "v0.11.6")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
