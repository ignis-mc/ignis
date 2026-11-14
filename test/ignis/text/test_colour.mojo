from ignis.text import ansi, clean, colourf, sprintf
from std.testing import TestSuite, assert_equal
from support.ui_vectors import UIVectors


def test_colourf_matches_gophertunnel() raises:
    var v = UIVectors()
    var i = 0
    while v.has(String(t"colourf.{i}.format")):
        var format = v.str(String(t"colourf.{i}.format"))
        var args = v.list(String(t"colourf.{i}.args"))
        var got = colourf(format, args)
        var want = v.str(String(t"colourf.{i}.out"))
        if got != want:
            raise Error(
                t"colourf case {i} ({repr(format)}): got {repr(got)}, want"
                t" {repr(want)}"
            )
        i += 1
    assert_equal(i, 36)


def test_clean_and_ansi_match_gophertunnel() raises:
    var v = UIVectors()
    var i = 0
    while v.has(String(t"clean.{i}.in")):
        var s = v.str(String(t"clean.{i}.in"))
        assert_equal(clean(s), v.str(String(t"clean.{i}.clean")))
        assert_equal(ansi(s), v.str(String(t"clean.{i}.ansi")))
        i += 1
    assert_equal(i, 6)


def test_sprintf() raises:
    assert_equal(sprintf("%v and %s", ["a", "b"]), "a and b")
    assert_equal(sprintf("100%%", []), "100%")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
