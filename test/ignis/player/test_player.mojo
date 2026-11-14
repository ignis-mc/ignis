from ignis.mgl64 import Vec3
from ignis.player.player import Player
from ignis.world.game_mode import GAME_MODE_CREATIVE, GAME_MODE_SURVIVAL
from minecraft.protocol.uuid import UUID
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)


def _player() raises -> Player:
    return Player("Steve", "123", UUID(), Vec3(0.5, 1, 0.5), GAME_MODE_CREATIVE)


def test_move() raises:
    var p = _player()
    assert_true(p.move(Vec3(1, 0, -1), 30, -10))
    assert_true(p.position() == Vec3(1.5, 1, -0.5))
    assert_almost_equal(p.rotation().yaw(), 30)
    assert_almost_equal(p.rotation().pitch(), -10)
    assert_false(p.on_ground())
    assert_false(p.move(Vec3(), 0, 0))
    assert_true(p.on_ground())


def test_chat_format() raises:
    assert_equal(_player().chat("hi there"), "<Steve> hi there")


def test_game_mode_stops_flying() raises:
    var p = _player()
    p.start_flying()
    p.set_game_mode(GAME_MODE_SURVIVAL)
    assert_false(p.flying())
    assert_equal(p.name_tag(), "Steve")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
