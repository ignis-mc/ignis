from ignis.internal.enum import enum_name
from std.testing import TestSuite, assert_equal


def test_enum_name() raises:
    assert_equal(enum_name("a,bc,d", 0), "a")
    assert_equal(enum_name("a,bc,d", 1), "bc")
    assert_equal(enum_name("a,bc,d", 2), "d")
    assert_equal(enum_name("a,bc,d", 3), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
