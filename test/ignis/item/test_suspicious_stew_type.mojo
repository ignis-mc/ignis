from ignis.entity.effect import SECOND
from ignis.entity.effect.saturation import Saturation
from ignis.entity.effect.night_vision import NightVision
from ignis.item.suspicious_stew import SuspiciousStew
from ignis.item.suspicious_stew_type import StewType, stew_types
from std.testing import TestSuite, assert_equal, assert_true


def test_effects() raises:
    var e = StewType.NIGHT_VISION_TORCHFLOWER.effects()
    assert_equal(len(e), 1)
    assert_equal(e[0].type_id(), NightVision.ID)
    assert_equal(e[0].duration(), 5 * SECOND)
    var s = StewType.SATURATION_ORCHID.effects()
    assert_equal(s[0].type_id(), Saturation.ID)
    assert_equal(s[0].duration(), SECOND * 3 // 10)
    for t in stew_types():
        assert_equal(len(t.effects()), 1)


def test_stew_round_trip() raises:
    assert_equal(len(SuspiciousStew.all_items()), 13)
    for it in SuspiciousStew.all_items():
        assert_true(SuspiciousStew.from_hash(it.hash()) == it)
        assert_equal(it.encode_item().meta, Int16(it.type.uint8()))
    var info = SuspiciousStew(type=StewType.WITHER).consume_info()
    assert_equal(info.food, 6)
    assert_equal(len(info.effects), 1)
    assert_true(not info.residue.empty())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
