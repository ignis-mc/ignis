"""Tests for `ignis.entity.experience`: levels and progress for amounts of
experience, against Dragonfly (`interop/health`)."""

from std.testing import TestSuite, assert_equal

from ignis.entity.experience import ExperienceManager

from support.entity_vectors import bits


def test_levels_match_dragonfly() raises:
    var n = 0
    with open("test/data/health/damage.txt", "r") as f:
        for raw in f.read().split("\n"):
            var p = String(raw).split("\t")
            if len(p) < 4 or String(p[0]) != "xp":
                continue
            var m = ExperienceManager()
            var r = m.add(Int(String(p[1])))
            assert_equal(r[0], Int(String(p[2])), String(raw))
            assert_equal(bits(r[1]), String(p[3]), String(raw))
            n += 1
    assert_equal(n, 12)


def test_set_level_keeps_progress() raises:
    var m = ExperienceManager()
    _ = m.add(100)
    var p = m.progress()
    m.set_level(20)
    assert_equal(m.level(), 20)
    assert_equal(Int(m.progress() * 100), Int(p * 100))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
