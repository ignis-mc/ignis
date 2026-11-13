from ignis.block.hash import AnyBlock
from ignis.block.stone import Stone
from ignis.world.sound import Sound
from ignis.world.sound.ambient import LightningThunder
from ignis.world.sound.block import BlockPlace, Note
from ignis.world.sound.custom import Custom
from ignis.world.sound.disc_type import DiscType, music_discs
from ignis.world.sound.entity import Attack
from ignis.world.sound.goat_horn import Horn, goat_horns
from ignis.world.sound.instrument import Instrument
from ignis.world.sound.item import CROSSBOW_LOADING_END, CrossbowLoad
from std.testing import TestSuite, assert_equal, assert_true


def _id[S: Sound](s: S) -> Int:
    return S.SOUND_ID


def test_sound_ids_are_distinct() raises:
    var ids = [
        _id(BlockPlace(block=AnyBlock(Stone()))),
        _id(Note(instrument=Instrument.BANJO, pitch=3)),
        _id(Attack(damage=True)),
        _id(CrossbowLoad(stage=CROSSBOW_LOADING_END)),
        _id(LightningThunder()),
        _id(Custom(name="x", volume=1, pitch=1)),
    ]
    for i in range(len(ids)):
        for j in range(i + 1, len(ids)):
            assert_true(ids[i] != ids[j])


def test_enums() raises:
    assert_equal(Instrument.PLING.int32(), 15)
    assert_equal(len(music_discs()), 21)
    assert_equal(String(DiscType.DISC_13), "13")
    assert_equal(DiscType.PIGSTEP.display_name(), "Pigstep")
    assert_equal(DiscType.CAT.display_name(), "cat")
    assert_equal(
        DiscType.CREATOR_MUSIC_BOX.display_name(), "Creator (Music Box)"
    )
    assert_equal(DiscType.RELIC.author(), "Aaron Cherof")
    assert_equal(DiscType.WAIT.author(), "C418")
    assert_equal(len(goat_horns()), 8)
    assert_equal(Horn.DREAM.name(), "Dream")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
