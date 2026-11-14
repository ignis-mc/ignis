from ignis.player.scoreboard import Scoreboard
from std.testing import TestSuite, assert_equal, assert_raises
from support.ui_vectors import UIVectors


def test_lines_match_dragonfly() raises:
    var v = UIVectors()
    var sb = Scoreboard("Test Board")
    _ = sb.write_string("a\nbbbbbbbbbbbbbbbb")
    sb.set(4, "x\n\n")
    assert_equal(sb.name(), v.str("scoreboard.name"))
    assert_equal(String("\x1f").join(sb.lines()), v.str("scoreboard.lines"))
    sb.set_descending()
    assert_equal(String("\x1f").join(sb.lines()), v.str("scoreboard.desc"))
    sb.remove_padding()
    assert_equal(String("\x1f").join(sb.lines()), v.str("scoreboard.nopad"))
    sb.remove(0)
    assert_equal(String("\x1f").join(sb.lines()), v.str("scoreboard.removed"))
    var full = Scoreboard("F")
    with assert_raises():
        _ = full.write_string(String("l\n") * 14)
    assert_equal(String(len(full.lines())), v.str("scoreboard.full_lines"))
    with assert_raises():
        full.set(15, "x")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
