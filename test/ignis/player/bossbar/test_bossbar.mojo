from ignis.player.bossbar import BossBar, Colour
from std.testing import TestSuite, assert_equal, assert_raises
from support.ui_vectors import UIVectors


def test_defaults_match_dragonfly() raises:
    var v = UIVectors()
    var b = BossBar("B\n")
    # Go: fmt.Sprintf("%q %v %v", text, health, colour).
    assert_equal(
        String(
            t'"B\\n"'
            t' {Int(BossBar().health_percentage())} {BossBar().colour().uint8()}'
        ),
        v.str("bossbar.default"),
    )
    assert_equal(b.text(), "B\n")
    assert_equal(b.with_colour(Colour.WHITE).colour().uint8(), 7)
    with assert_raises():
        _ = b.with_health_percentage(1.5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
