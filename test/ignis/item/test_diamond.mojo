from ignis.item.diamond import Diamond
from ignis.item.register import vanilla_item_registry
from std.testing import TestSuite, assert_equal, assert_true
from support.item_vectors import load_item_vectors


def test_hash_round_trips() raises:
    for it in Diamond.all_items():
        assert_true(Diamond.from_hash(it.hash()) == it)


def test_runtime_id_matches_dragonfly() raises:
    var v = load_item_vectors()
    var id = vanilla_item_registry().item_runtime_id(Diamond()).value()
    assert_equal(String(id.runtime_id), v["item.diamond.rid"])
    assert_equal(String(id.meta), v["item.diamond.meta"])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
