from ignis.entity.effect.hunger import Hunger
from ignis.entity.effect.poison import Poison
from ignis.item.chicken import Chicken
from ignis.item.cod import Cod
from ignis.item.dried_kelp import DriedKelp
from ignis.item.honey_bottle import HoneyBottle
from ignis.item.item import DEFAULT_CONSUME_DURATION
from ignis.item.mutton import Mutton
from ignis.item.porkchop import Porkchop
from ignis.item.rabbit import Rabbit
from ignis.item.salmon import Salmon
from std.testing import TestSuite, assert_equal, assert_true


def test_cooked_round_trip() raises:
    for c in [True, False]:
        assert_true(
            Chicken.from_hash(Chicken(cooked=c).hash()) == Chicken(cooked=c)
        )
        assert_true(Cod.from_hash(Cod(cooked=c).hash()) == Cod(cooked=c))
        assert_true(
            Mutton.from_hash(Mutton(cooked=c).hash()) == Mutton(cooked=c)
        )
        assert_true(Porkchop.from_hash(Porkchop(cooked=c).hash()).cooked == c)
        assert_true(Rabbit.from_hash(Rabbit(cooked=c).hash()).cooked == c)
        assert_true(Salmon.from_hash(Salmon(cooked=c).hash()).cooked == c)
    assert_equal(
        Chicken(cooked=True).encode_item().name, "minecraft:cooked_chicken"
    )


def test_raw_chicken_hunger_chance() raises:
    var info = Chicken().consume_info()
    assert_equal(len(info.effects), 1)
    assert_equal(info.effects[0].effect.type_id(), Hunger.ID)
    assert_equal(info.effects[0].chance, 0.3)
    assert_equal(len(Chicken(cooked=True).consume_info().effects), 0)
    var smelt = Chicken().smelt_info()
    assert_true(smelt.food)
    assert_true(Chicken(cooked=True).smelt_info().product.empty())


def test_durations() raises:
    assert_equal(DriedKelp().consume_duration(), DEFAULT_CONSUME_DURATION // 2)
    assert_equal(HoneyBottle().consume_duration(), 2012)
    assert_equal(HoneyBottle().consume_info().removed_effects[0], Poison.ID)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
