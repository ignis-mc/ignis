from ignis.world.chunk.palette import Palette
from ignis.world.chunk.paletted_storage import PalettedStorage
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_grows_through_every_size() raises:
    var s = PalettedStorage.empty(0)
    assert_equal(s.bits_per_index(), 0)
    var n = 1
    for size in [1, 2, 3, 4, 5, 6, 8, 16]:
        while n < min(1 << size, 4096):
            s.set(
                UInt8(n % 16), UInt8((n // 16) % 16), UInt8(n // 256), UInt32(n)
            )
            n += 1
        assert_equal(Int(s.bits_per_index()), size)
    # Every value survives the resizes.
    for i in range(1, 4096):
        assert_equal(
            s.at(UInt8(i % 16), UInt8((i // 16) % 16), UInt8(i // 256)),
            UInt32(i),
        )
    assert_equal(s.at(0, 0, 0), 0)


def test_coordinates_wrap() raises:
    var s = PalettedStorage.empty(0)
    s.set(17, 18, 19, 5)
    assert_equal(s.at(1, 2, 3), 5)
    assert_equal(s.palette_index(1, 2, 3), 1)


def test_equal_follows_dragonfly() raises:
    var a = PalettedStorage.empty(3)
    var b = PalettedStorage.empty(3)
    # Zero-bit storages never compare equal.
    assert_false(a.equal(b))
    a.set(0, 0, 0, 4)
    b.set(0, 0, 0, 4)
    assert_true(a.equal(b))
    b.set(0, 0, 1, 4)
    assert_false(a.equal(b))
    # Nor do storages whose first palette value is 0.
    var c = PalettedStorage.empty(0)
    var d = PalettedStorage.empty(0)
    c.set(0, 0, 0, 1)
    d.set(0, 0, 0, 1)
    assert_false(c.equal(d))


def test_compact() raises:
    var s = PalettedStorage.empty(0)
    for i in range(20):
        s.set(UInt8(i % 16), 0, UInt8(i // 16), UInt32(i + 1))
    assert_equal(s.bits_per_index(), 5)
    for i in range(20):
        s.set(UInt8(i % 16), 0, UInt8(i // 16), 0)
    s.set(5, 5, 5, 7)
    s.compact()
    assert_equal(s.bits_per_index(), 1)
    assert_equal(s.palette().values(), [0, 7])
    assert_equal(s.at(5, 5, 5), 7)
    assert_equal(s.at(0, 0, 0), 0)
    # A palette with one entry compacts to 0 bits per index.
    var one = PalettedStorage(List[UInt32](), Palette(0, [9]))
    one.compact()
    assert_equal(one.bits_per_index(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
