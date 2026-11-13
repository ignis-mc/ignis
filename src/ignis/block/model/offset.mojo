"""The random horizontal offset of some plants, ported from Dragonfly
`server/block/model/offset.go`.
"""

from std.math import floor

from ...internal.mcrandom import Xoroshiro128PlusPlus, mix_stafford13
from ...mgl64 import Vec3
from ..cube.pos import Pos


def random_offset(pos: Pos, mn: Float32, mx: Float32, steps: Int) -> Vec3:
    """Returns the horizontal offset the client gives the model of a block
    at a position, such as bamboo (Go `randomOffset`).

    Args:
        pos: The position of the block.
        mn: The minimum offset.
        mx: The maximum offset.
        steps: The number of distinct offsets.

    Returns:
        The offset, with Y always 0.
    """
    var seed = _offset_seed(Int32(pos.x()), Int32(pos.z()))
    var s0 = mix_stafford13(seed)
    var s1 = mix_stafford13(seed + 0x9E3779B97F4A7C15)
    var prng = Xoroshiro128PlusPlus(s0, s1)
    var x = _offset_value(mn, mx, steps, _random_float32(prng.next()))
    # The Y offset is always zero, but its draw is still consumed.
    _ = prng.next()
    var z = _offset_value(mn, mx, steps, _random_float32(prng.next()))
    return Vec3(Float64(x), 0, Float64(z))


def _offset_seed(x: Int32, z: Int32) -> UInt64:
    var v = Int64(z) * 116129781 ^ Int64(x) * 0x2FC20F
    v = Int64(Int32(UInt64(v * (v * 42317861 + 11)) >> 16))
    return UInt64(v) ^ 0x6A09E667F3BCC909


def _random_float32(random: UInt64) -> Float32:
    return Float32(random >> 40) * (1.0 / 16777216.0)


def _offset_value(
    mn: Float32, mx: Float32, steps: Int, random: Float32
) -> Float32:
    if mn >= mx:
        return mn
    if steps == 1:
        return (mn + mx) * 0.5
    if steps > 1:
        var index = Float32(floor(Float64(Float32(steps) * random)))
        return mn + index * (mx - mn) / Float32(steps - 1)
    return mn + (mx - mn) * random
