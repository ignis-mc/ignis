from ignis.item.stick import Stick
from ignis.item.register import vanilla_item_registry
from std.testing import TestSuite, assert_equal, assert_true
from support.item_vectors import load_item_vectors


def test_hash_round_trips() raises:
    for it in Stick.all_items():
        assert_true(Stick.from_hash(it.hash()) == it)


def test_runtime_id_matches_dragonfly() raises:
    var v = load_item_vectors()
    var id = vanilla_item_registry().item_runtime_id(Stick()).value()
    assert_equal(String(id.runtime_id), v["item.stick.rid"])
    assert_equal(String(id.meta), v["item.stick.meta"])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
