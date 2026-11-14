from ignis.internal.json import (
    JSON_ARRAY,
    JSON_NULL,
    JSON_NUMBER,
    JSON_OBJECT,
    JSON_STRING,
    JsonDoc,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_parse_nested() raises:
    var d = JsonDoc(
        '{"a": [1, -2, {"b": "x\\u00e9\\n"}], "t": true, "n": null, "e": {},'
        ' "f": []}'.as_bytes()
    )
    var r = d.root()
    assert_equal(d.kind(r), JSON_OBJECT)
    var keys = List[String]()
    for c in d.children(r):
        keys.append(d.key(c))
    assert_equal(keys, ["a", "t", "n", "e", "f"])
    var a = d.get(r, "a").value()
    assert_equal(d.kind(a), JSON_ARRAY)
    var items = d.children(a)
    assert_equal(len(items), 3)
    assert_equal(d.as_int(items[1]), -2)
    assert_equal(d.as_string(d.get(items[2], "b").value()), "xé\n")
    assert_true(d.as_bool(d.get(r, "t").value()))
    assert_equal(d.kind(d.get(r, "n").value()), JSON_NULL)
    assert_equal(len(d.children(d.get(r, "e").value())), 0)
    assert_false(Bool(d.get(r, "zzz")))


def test_errors() raises:
    with assert_raises(contains="json"):
        _ = JsonDoc('{"a": }'.as_bytes())
    with assert_raises(contains="trailing"):
        _ = JsonDoc("1 2".as_bytes())
    with assert_raises(contains="unterminated"):
        _ = JsonDoc('"abc'.as_bytes())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
