from ignis.leveldb.filter import (
    BloomGenerator,
    FilterBlockReader,
    FilterBlockWriter,
    bloom_may_contain,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _num(i: Int) -> List[UInt8]:
    return [
        UInt8(i & 0xFF),
        UInt8((i >> 8) & 0xFF),
        UInt8((i >> 16) & 0xFF),
        UInt8(i >> 24),
    ]


def test_empty_and_small() raises:
    # goleveldb filter/bloom_test.go.
    var g = BloomGenerator(10)
    var f = List[UInt8]()
    g.generate(f)
    assert_false(bloom_may_contain(f, "hello".as_bytes()))
    var g2 = BloomGenerator(10)
    g2.add("hello".as_bytes())
    g2.add("world".as_bytes())
    var f2 = List[UInt8]()
    g2.generate(f2)
    assert_true(bloom_may_contain(f2, "hello".as_bytes()))
    assert_true(bloom_may_contain(f2, "world".as_bytes()))
    assert_false(bloom_may_contain(f2, "x".as_bytes()))
    assert_false(bloom_may_contain(f2, "foo".as_bytes()))


def test_varying_lengths_false_positive_rate() raises:
    var n = 10000
    var g = BloomGenerator(10)
    for i in range(n):
        g.add(_num(i))
    var f = List[UInt8]()
    g.generate(f)
    assert_true(len(f) <= n * 10 // 8 + 40)
    for i in range(n):
        assert_true(bloom_may_contain(f, _num(i)))
    var fp = 0
    for i in range(10000):
        if bloom_may_contain(f, _num(i + 1000000000)):
            fp += 1
    # Both hash variants are checked, so allow about twice the usual 1%.
    assert_true(fp < 400)


def test_filter_block() raises:
    var w = FilterBlockWriter(10)
    w.flush(0)
    w.add("foo".as_bytes())
    w.add("bar".as_bytes())
    w.flush(100)
    w.add("box".as_bytes())
    w.flush(3100)
    w.add("hello".as_bytes())
    var block = w.finish()
    var r = FilterBlockReader(block^)
    assert_true(r.may_contain(0, "foo".as_bytes()))
    assert_true(r.may_contain(0, "bar".as_bytes()))
    assert_false(r.may_contain(0, "hello".as_bytes()))
    assert_true(r.may_contain(3100, "hello".as_bytes()))
    assert_false(r.may_contain(3100, "foo".as_bytes()))
    # Offsets past the last filter are not ruled out.
    assert_true(r.may_contain(1 << 30, "anything".as_bytes()))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
