from ignis.internal.gojson import (
    JsonObject,
    format_float,
    quote,
    quote_bytes,
    valid_utf8,
)
from std.memory import bitcast
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.ui_vectors import UIVectors


def _bits(s: String) raises -> Float64:
    var v = UInt64(0)
    for b in s.as_bytes():
        var d = Int(b) - 48 if Int(b) <= 57 else Int(b) - 87
        v = v * 16 + UInt64(d)
    return bitcast[DType.float64](v)


def test_floats_match_encoding_json() raises:
    var v = UIVectors()
    var i = 0
    while v.has(String(t"float.{i}.in")):
        var f = _bits(v.str(String(t"float.{i}.in")))
        assert_equal(
            format_float(f), v.str(String(t"float.{i}.out")), String(f)
        )
        i += 1
    assert_equal(i, 22)


def test_strings_match_encoding_json() raises:
    var v = UIVectors()
    var i = 0
    while v.has(String(t"quote.{i}.in")):
        var raw = v.bytes(String(t"quote.{i}.in"))
        var want = v.str(String(t"quote.{i}.out"))
        # Some inputs are invalid UTF-8 on purpose; a String cannot hold them.
        assert_equal(quote_bytes(raw), want, String(i))
        if valid_utf8(raw):
            assert_equal(quote(String(unsafe_from_utf8=raw)), want)
        i += 1
    assert_equal(i, 10)


def test_object_keys_are_sorted() raises:
    var m = JsonObject()
    m.string("type", "x")
    m.int("b", 2)
    m.bool("a", True)
    assert_equal(m.encode(), '{"a":true,"b":2,"type":"x"}')
    assert_true(valid_utf8("é".as_bytes()))
    assert_false(valid_utf8([UInt8(0xFF)]))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
