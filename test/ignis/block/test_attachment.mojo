from ignis.block.attachment import (
    Attachment,
    attachment_from_uint8,
    standing_attachment,
    wall_attachment,
)
from ignis.block.banner_pattern_type import (
    BannerPatternType,
    banner_pattern_by_id,
    banner_pattern_id,
    banner_pattern_types,
)
from ignis.block.cube.direction import Direction
from ignis.block.cube.orientation import Orientation
from ignis.block.skull import Skull
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_uint8() raises:
    var w = wall_attachment(Direction.EAST)
    assert_equal(Int(w.uint8()), 6)
    assert_equal(Int(w.face_uint8()), 6)
    var s = standing_attachment(Orientation(5))
    assert_equal(Int(s.uint8()), 11)
    assert_equal(Int(s.face_uint8()), 1)
    assert_true(attachment_from_uint8(Int(w.uint8())) == w)
    assert_true(attachment_from_uint8(Int(s.uint8())) == s)
    assert_true(Attachment() == standing_attachment(Orientation(0)))


def test_rotate_right_rotates_right() raises:
    # Dragonfly's RotateRight rotates left.
    var w = wall_attachment(Direction.NORTH)
    assert_true(w.rotate_right().facing() == Direction.EAST)
    assert_true(w.rotate_left().facing() == Direction.WEST)
    var s = standing_attachment(Orientation(4))
    assert_equal(Int(s.rotate_right().orientation()), 8)
    assert_equal(Int(s.rotate_left().orientation()), 0)


def test_skull_ignores_standing_orientation() raises:
    # Go hashes skulls with FaceUint8: the orientation is not part of the
    # state.
    var a = Skull(attach=standing_attachment(Orientation(7)))
    assert_equal(
        a.hash(), Skull(attach=standing_attachment(Orientation(0))).hash()
    )


def test_banner_pattern_ids() raises:
    assert_equal(len(banner_pattern_types()), 42)
    assert_equal(banner_pattern_id(BannerPatternType.BORDER), "bo")
    assert_equal(banner_pattern_id(BannerPatternType.GUSTER), "gus")
    assert_true(
        banner_pattern_by_id("cs").value() == BannerPatternType.STRIPE_CENTRE
    )
    assert_false(Bool(banner_pattern_by_id("nope")))
    assert_equal(String(BannerPatternType.STRIPE_CENTRE), "stripe_center")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
