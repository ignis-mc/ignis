from ignis.leveldb.key import (
    KEY_MAX_SEQ,
    KEY_TYPE_VAL,
    compare_internal,
    internal_key,
)
from ignis.leveldb.memdb import MemDB
from std.testing import TestSuite, assert_equal, assert_true


def test_sorted_iteration_and_find() raises:
    var m = MemDB()
    # Insert in a scrambled order, two versions of each key.
    for i in range(1000):
        var k = (i * 7919) % 1000
        var key = String("k", k).as_bytes()
        m.put(
            internal_key(key, UInt64(i + 1), KEY_TYPE_VAL), String(i).as_bytes()
        )
        m.put(
            internal_key(key, UInt64(i + 5000), KEY_TYPE_VAL),
            String("new", i).as_bytes(),
        )
    assert_equal(len(m), 2000)
    var node = m.first()
    var prev = List[UInt8]()
    var n = 0
    while node != 0:
        var k = List[UInt8](m.key_at(node))
        if n > 0:
            assert_equal(compare_internal(prev, k), -1)
        prev = k^
        node = m.next(node)
        n += 1
    assert_equal(n, 2000)
    var f = m.find_ge(internal_key("k42".as_bytes(), KEY_MAX_SEQ, KEY_TYPE_VAL))
    assert_true(f != 0)
    assert_true(String(from_utf8=m.value_at(f)).startswith("new"))


def test_replace_identical_key() raises:
    var m = MemDB()
    var k = internal_key("a".as_bytes(), 1, KEY_TYPE_VAL)
    m.put(k, "x".as_bytes())
    m.put(k, "yz".as_bytes())
    assert_equal(len(m), 1)
    assert_equal(
        List[UInt8](m.value_at(m.first())), List[UInt8]("yz".as_bytes())
    )
    assert_equal(m.size(), len(k) + 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
