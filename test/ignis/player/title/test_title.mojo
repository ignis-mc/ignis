from ignis.player.title import Title
from std.testing import TestSuite, assert_equal


def test_defaults_and_formatting() raises:
    var t = Title("Hi\n")
    assert_equal(t.text(), "Hi")
    assert_equal(t.duration_ms(), 2000)
    assert_equal(t.fade_in_duration_ms(), 50)
    assert_equal(t.fade_out_duration_ms(), 50)
    var u = t.with_subtitle("s").with_action_text("a\n\n")
    assert_equal(u.subtitle(), "s")
    assert_equal(u.action_text(), "a\n")
    assert_equal(t.subtitle(), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
