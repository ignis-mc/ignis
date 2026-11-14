from ignis.player.chat import (
    message_bed_too_far,
    message_join,
    message_sleeping,
    translate,
)
from std.testing import TestSuite, assert_equal, assert_raises, assert_true
from support.ui_vectors import UIVectors


def test_translations_match_dragonfly() raises:
    var v = UIVectors()
    var j = message_join().f(["Steve"])
    assert_equal(j.string(), v.str("chat.join.string"))
    assert_equal(j.resolve("en_GB"), v.str("chat.join.resolve"))
    assert_equal(String("\x1f").join(j.parameters()), v.str("chat.join.params"))
    var s = message_sleeping().f(["Alex", "3"])
    assert_equal(s.string(), v.str("chat.sleeping.string"))
    assert_equal(s.resolve(), v.str("chat.sleeping.resolve"))
    assert_equal(
        String("\x1f").join(s.parameters()), v.str("chat.sleeping.params")
    )
    assert_equal(message_bed_too_far().f().string(), v.str("chat.bed.string"))
    assert_equal(message_bed_too_far().resolve(), v.str("chat.bed.resolve"))


def test_wrong_argument_count_raises() raises:
    with assert_raises():
        _ = message_join().f()
    assert_true(not translate("%x", 0, "x").zero())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
