from ignis.world.mcdb.leveldat.version import (
    VERSION,
    minimum_compatible_client_version,
)
from std.testing import TestSuite, assert_equal


def test_version() raises:
    assert_equal(VERSION, 10)
    assert_equal(minimum_compatible_client_version(), [Int32(1), 26, 60, 0, 0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
