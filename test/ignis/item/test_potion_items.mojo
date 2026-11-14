from ignis.item.arrow import Arrow
from ignis.item.lingering_potion import LingeringPotion
from ignis.item.potion import Potion
from ignis.item.potion.potion import Potion as PotionType
from ignis.item.splash_potion import SplashPotion
from std.testing import TestSuite, assert_equal, assert_true


def test_hash_round_trips() raises:
    for it in Potion.all_items():
        assert_true(Potion.from_hash(it.hash()) == it)
    for it in SplashPotion.all_items():
        assert_true(SplashPotion.from_hash(it.hash()) == it)
    for it in LingeringPotion.all_items():
        assert_true(LingeringPotion.from_hash(it.hash()) == it)
    for it in Arrow.all_items():
        assert_true(Arrow.from_hash(it.hash()) == it)


def test_arrow_meta() raises:
    assert_equal(len(Arrow.all_items()), 39)
    assert_equal(Arrow().encode_item().meta, 0)
    assert_equal(Arrow(tip=PotionType.AWKWARD).encode_item().meta, 0)
    assert_equal(Arrow(tip=PotionType.NIGHT_VISION).encode_item().meta, 6)


def test_potion_consume() raises:
    var info = Potion(type=PotionType.TURTLE_MASTER).consume_info()
    assert_equal(len(info.effects), 2)
    assert_equal(info.residue.count(), 1)
    assert_equal(Potion(type=PotionType.HARMING).encode_item().meta, 23)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
