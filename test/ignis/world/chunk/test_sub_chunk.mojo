from ignis.world.chunk.sub_chunk import LightArray, SubChunk, light_index
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_layers_and_blocks() raises:
    var s = SubChunk(100)
    assert_true(s.empty())
    assert_equal(s.block(1, 2, 3, 0), 100)
    s.set_block(1, 2, 3, 1, 5)
    assert_equal(len(s.layers()), 2)
    # Layer 0 holds only air, but there are two layers.
    assert_false(s.empty())
    assert_equal(s.block(1, 2, 3, 1), 5)
    assert_equal(s.block(1, 2, 3, 0), 100)
    assert_equal(s.block(1, 2, 3, 4), 100)


def test_compact_drops_air_layers() raises:
    var s = SubChunk(100)
    s.set_block(0, 0, 0, 1, 5)
    s.set_block(0, 0, 0, 1, 100)
    s.compact()
    assert_equal(len(s.layers()), 0)
    assert_true(s.empty())


def test_equals() raises:
    var a = SubChunk(100)
    var b = SubChunk(100)
    assert_true(a.equals(b))
    a.set_block(0, 0, 0, 0, 5)
    b.set_block(0, 0, 0, 0, 5)
    assert_true(a.equals(b))
    b.set_block(1, 0, 0, 0, 5)
    assert_false(a.equals(b))
    assert_false(SubChunk(1).equals(SubChunk(2)))


def test_light_starts_at_zero_and_is_copied_on_write() raises:
    var s = SubChunk(100)
    assert_equal(s.sky_light(1, 2, 3), 0)
    assert_equal(s.block_light(1, 2, 3), 0)
    assert_true(s.sky_light_array().shared())
    s.set_sky_light(1, 2, 3, 9)
    s.set_block_light(1, 3, 3, 4)
    assert_false(s.sky_light_array().shared())
    assert_equal(s.sky_light(1, 2, 3), 9)
    assert_equal(s.sky_light(1, 3, 3), 0)
    assert_equal(s.block_light(1, 3, 3), 4)
    assert_equal(s.block_light(1, 2, 3), 0)
    s.clear_light()
    assert_true(s.sky_light_array().shared())
    assert_equal(s.sky_light(1, 2, 3), 0)


def test_light_array_layout_matches_dragonfly() raises:
    # Go: index x<<8 | z<<4 | y, the low nibble of byte index>>1 for even
    # indices, the high nibble for odd ones.
    var full = LightArray(0xFF)
    assert_equal(full.get(light_index(15, 15, 15)), 15)
    full.set(light_index(0, 1, 0), 3)
    var b = full.bytes()
    assert_equal(len(b), 2048)
    assert_equal(b[0], 0x3F)
    assert_equal(b[1], 0xFF)
    var other = LightArray(0xFF)
    assert_true(other.same_shared(LightArray(0xFF)))
    assert_false(other.same_shared(LightArray(0)))
    assert_false(other.same_shared(full))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
