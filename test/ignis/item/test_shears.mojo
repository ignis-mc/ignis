from ignis.item.register import vanilla_item_registry
from ignis.item.shears import Shears
from std.testing import TestSuite, assert_equal, assert_true
from support.item_vectors import load_item_vectors


def test_hash_round_trips() raises:
    for it in Shears.all_items():
        assert_true(Shears.from_hash(it.hash()) == it)


def test_runtime_id_matches_dragonfly() raises:
    var v = load_item_vectors()
    var id = vanilla_item_registry().item_runtime_id(Shears()).value()
    assert_equal(String(id.runtime_id), v["item.shears.rid"])


def test_max_count() raises:
    assert_equal(Shears().max_count(), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
