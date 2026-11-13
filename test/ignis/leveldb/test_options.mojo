from ignis.leveldb.compress import FLATE_COMPRESSION
from ignis.leveldb.options import KIB, MIB, Options
from std.testing import TestSuite, assert_equal, assert_false


def test_goleveldb_defaults() raises:
    var o = Options()
    assert_equal(o.block_size, 4 * KIB)
    assert_equal(o.block_restart_interval, 16)
    assert_equal(o.compression, FLATE_COMPRESSION)
    assert_equal(o.filter_bits_per_key, 0)
    assert_equal(o.write_buffer, 4 * MIB)
    assert_equal(o.compaction_table_size, 2 * MIB)
    assert_equal(o.compaction_l0_trigger, 4)
    assert_equal(o.compaction_total_size, 10 * MIB)
    assert_false(o.sync)
    assert_false(o.strict)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
