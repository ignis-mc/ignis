from ignis.internal.rand import PCG, Rand
from std.memory import bitcast
from std.testing import TestSuite, assert_equal, assert_true
from support.world_vectors import load_vectors


def test_matches_go() raises:
    # interop/world: rand.New(rand.NewPCG(1, 2)).
    var v = load_vectors()
    var r = Rand(1, 2)
    assert_equal(String(r.uint64()), v["rand.uint64.0"])
    assert_equal(String(r.uint64()), v["rand.uint64.1"])
    assert_equal(String(r.int_n(8400)), v["rand.intn_8400"])
    assert_equal(String(r.int_n(600)), v["rand.intn_600"])
    assert_equal(String(r.int32()), v["rand.int32"])
    assert_equal(String(r.int_n(1 << 20)), v["rand.intn_pow2"])
    assert_equal(String(r.int_n(1000000007)), v["rand.intn_large"])
    var bits = bitcast[DType.uint64](r.float64())
    assert_equal(bits, UInt64(atol(v["rand.float64_bits"], 16)))


def test_int_n_in_range() raises:
    var r = Rand(7, 9)
    for _ in range(1000):
        var x = r.int_n(13)
        assert_true(x >= 0 and x < 13)


def test_pcg_copy_is_independent() raises:
    var a = PCG(3, 4)
    var b = a.copy()
    assert_equal(a.uint64(), b.uint64())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
