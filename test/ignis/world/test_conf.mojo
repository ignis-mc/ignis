from ignis.world.conf import Config
from ignis.world.dimension import NETHER
from ignis.world.provider import MemoryProvider
from std.testing import TestSuite, assert_equal, assert_true
from support.world_runtime import TestWorld, flat, test_registry


def test_defaults() raises:
    var br = test_registry()
    var conf = Config[TestWorld](flat(br[]), MemoryProvider(), br)
    assert_equal(conf.save_interval_ms, 600_000)
    assert_equal(conf.chunk_unload_interval_ms, 120_000)
    assert_equal(conf.random_tick_speed, 3)
    assert_true(conf.dim == conf.dim)
    conf.dim = NETHER
    # Without a seed, the world seeds itself from the operating system.
    var w = conf^.new(1000)
    assert_true(w.dimension() == NETHER)
    assert_equal(w.next_deadline_ms(), 1050)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
