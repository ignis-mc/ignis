"""The random number generators Minecraft uses, ported from Dragonfly
`server/internal/mcrandom`.
"""

from std.bit import rotate_bits_left


def mix_stafford13(seed: UInt64) -> UInt64:
    """Mixes a seed with Stafford's variant 13 of the MurmurHash3 finaliser
    (Go `MixStafford13`)."""
    var s = (seed ^ (seed >> 30)) * 0xBF58476D1CE4E5B9
    s = (s ^ (s >> 27)) * 0x94D049BB133111EB
    return s ^ (s >> 31)


struct Xoroshiro128PlusPlus(Movable):
    """The xoroshiro128++ generator (Go `Xoroshiro128PlusPlus`)."""

    var _seed0: UInt64
    var _seed1: UInt64

    def __init__(out self, seed0: UInt64, seed1: UInt64):
        """Creates the generator (Go `NewXoroshiro128PlusPlus`)."""
        self._seed0 = seed0
        self._seed1 = seed1

    def next(mut self) -> UInt64:
        """Returns the next value (Go `Next`)."""
        var s0 = self._seed0
        var s1 = self._seed1
        var result = rotate_bits_left[17](s0 + s1) + s0
        s1 ^= s0
        self._seed0 = rotate_bits_left[49](s0) ^ s1 ^ (s1 << 21)
        self._seed1 = rotate_bits_left[28](s1)
        return result
