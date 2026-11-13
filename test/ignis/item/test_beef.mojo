from ignis.item.beef import Beef
from ignis.item.register import vanilla_item_registry
from std.testing import TestSuite, assert_equal, assert_true
from support.item_vectors import load_item_vectors


def test_hash_round_trips() raises:
    for it in Beef.all_items():
        assert_true(Beef.from_hash(it.hash()) == it)


def test_runtime_ids_match_dragonfly() raises:
    var v = load_item_vectors()
    var reg = vanilla_item_registry()
    assert_equal(
        String(reg.item_runtime_id(Beef()).value().runtime_id),
        v["item.beef.rid"],
    )
    assert_equal(
        String(reg.item_runtime_id(Beef(cooked=True)).value().runtime_id),
        v["item.cooked_beef.rid"],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
