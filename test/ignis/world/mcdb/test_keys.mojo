from ignis.world.mcdb.keys import (
    KEY_3D_DATA,
    KEY_FINALISATION,
    KEY_LEGACY_STATES,
    KEY_SUB_CHUNK_DATA,
    KEY_VERSION,
    KEY_VERSION_OLD,
)
from std.testing import TestSuite, assert_equal


def test_values() raises:
    assert_equal(KEY_SUB_CHUNK_DATA, UInt8(ord("/")))
    assert_equal(KEY_VERSION, UInt8(ord(",")))
    assert_equal(KEY_VERSION_OLD, UInt8(ord("v")))
    assert_equal(KEY_3D_DATA, UInt8(ord("+")))
    assert_equal(KEY_FINALISATION, UInt8(ord("6")))
    assert_equal(KEY_LEGACY_STATES, UInt8(ord("|")))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
