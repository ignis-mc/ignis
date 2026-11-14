from ignis.session.armour_trim import trim_data
from minecraft.protocol.writer import Writer
from std.testing import TestSuite, assert_equal, assert_true


def test_trim_data_matches_dragonfly() raises:
    """The TrimData packet has the bytes Dragonfly sends (`trim_data.bin`
    from `interop/items`)."""
    var pk = trim_data()
    assert_equal(len(pk.patterns), 18)
    assert_equal(len(pk.materials), 11)
    var w = Writer(0)
    pk.marshal(w)
    var bytes = w.take()
    var expected: List[UInt8]
    with open("test/data/items/trim_data.bin", "r") as f:
        expected = f.read_bytes()
    assert_true(bytes == expected, "TrimData bytes match")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
