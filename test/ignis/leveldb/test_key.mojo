from ignis.leveldb.key import (
    KEY_MAX_NUM,
    KEY_TYPE_DEL,
    KEY_TYPE_VAL,
    compare_internal,
    internal_key,
    key_seq,
    key_type,
    separator,
    successor,
    ukey,
    valid_internal_key,
)
from ignis.leveldb.util import get_u64
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_internal_key_layout() raises:
    var k = internal_key("abc".as_bytes(), 0x123456, KEY_TYPE_VAL)
    assert_equal(len(k), 11)
    assert_equal(get_u64(k, 3), (UInt64(0x123456) << 8) | 1)
    assert_equal(List[UInt8](ukey(k)), List[UInt8]("abc".as_bytes()))
    assert_equal(key_seq(k), 0x123456)
    assert_equal(key_type(k), KEY_TYPE_VAL)
    assert_true(valid_internal_key(k))
    assert_false(valid_internal_key([UInt8(1), 2]))


def test_order() raises:
    var a1 = internal_key("a".as_bytes(), 1, KEY_TYPE_VAL)
    var a2 = internal_key("a".as_bytes(), 2, KEY_TYPE_DEL)
    var b1 = internal_key("b".as_bytes(), 1, KEY_TYPE_VAL)
    # Newer versions of a user key sort first.
    assert_equal(compare_internal(a2, a1), -1)
    assert_equal(compare_internal(a1, b1), -1)
    assert_equal(compare_internal(b1, a2), 1)
    assert_equal(compare_internal(a1, a1.copy()), 0)


def test_separator_and_successor() raises:
    # goleveldb bytesComparer: shortened only if a byte can be incremented
    # without reaching b, and only if that makes the key shorter.
    var s = separator(
        internal_key("abcdef".as_bytes(), 5, KEY_TYPE_VAL),
        internal_key("abzz".as_bytes(), 9, KEY_TYPE_VAL),
    )
    assert_true(Bool(s))
    assert_equal(List[UInt8](ukey(s.value())), List[UInt8]("abd".as_bytes()))
    assert_equal(get_u64(s.value(), 3), KEY_MAX_NUM)
    assert_false(
        Bool(
            separator(
                internal_key("abc".as_bytes(), 5, KEY_TYPE_VAL),
                internal_key("abd".as_bytes(), 9, KEY_TYPE_VAL),
            )
        )
    )
    var t = successor(internal_key([UInt8(0xFF), 0x05, 0x07], 1, KEY_TYPE_VAL))
    assert_equal(List[UInt8](ukey(t.value())), [UInt8(0xFF), 0x06])
    assert_false(
        Bool(successor(internal_key([UInt8(0xFF), 0xFF], 1, KEY_TYPE_VAL)))
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
