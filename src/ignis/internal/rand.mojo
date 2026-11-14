"""Go's `math/rand/v2` PCG source and the `Rand` methods Dragonfly uses.

Dragonfly's worlds draw random numbers from a `rand.Rand` over `rand.PCG`.
This is the same generator, so a world seeded alike draws the same numbers.
"""

from std.os import abort


struct PCG(Copyable, Defaultable):
    """A PCG generator with 128-bit state and DXSM output (Go `rand.PCG`)."""

    var _hi: UInt64
    var _lo: UInt64

    def __init__(out self):
        """Creates a generator seeded with zeros."""
        self._hi = 0
        self._lo = 0

    def __init__(out self, seed1: UInt64, seed2: UInt64):
        """Creates a generator (Go `NewPCG`)."""
        self._hi = seed1
        self._lo = seed2

    def _next(mut self) -> Tuple[UInt64, UInt64]:
        comptime MUL_HI: UInt64 = 2549297995355413924
        comptime MUL_LO: UInt64 = 4865540595714422341
        comptime INC_HI: UInt64 = 6364136223846793005
        comptime INC_LO: UInt64 = 1442695040888963407
        # state = state * mul + inc (mod 2^128)
        var wide = UInt128(self._lo) * UInt128(MUL_LO)
        var hi = UInt64(wide >> 64)
        var lo = UInt64(wide & 0xFFFFFFFFFFFFFFFF)
        hi += self._hi * MUL_LO + self._lo * MUL_HI
        var sum = UInt128(lo) + UInt128(INC_LO)
        lo = UInt64(sum & 0xFFFFFFFFFFFFFFFF)
        hi = hi + INC_HI + UInt64(sum >> 64)
        self._lo = lo
        self._hi = hi
        return (hi, lo)

    def uint64(mut self) -> UInt64:
        """Returns a uniformly distributed 64-bit value (Go `Uint64`)."""
        var state = self._next()
        var hi = state[0]
        var lo = state[1]
        comptime CHEAP_MUL: UInt64 = 0xDA942042E4DD58B5
        hi ^= hi >> 32
        hi *= CHEAP_MUL
        hi ^= hi >> 48
        hi *= lo | 1
        return hi


struct Rand(Copyable, Defaultable):
    """A source of random numbers (Go `rand.Rand` over a `rand.PCG`)."""

    var _src: PCG

    def __init__(out self):
        """Creates a generator seeded with zeros."""
        self._src = PCG()

    def __init__(out self, seed1: UInt64, seed2: UInt64):
        """Creates a generator (Go `rand.New(rand.NewPCG(seed1, seed2))`)."""
        self._src = PCG(seed1, seed2)

    def uint64(mut self) -> UInt64:
        """Returns a uniformly distributed 64-bit value (Go `Uint64`)."""
        return self._src.uint64()

    def uint32(mut self) -> UInt32:
        """Returns a uniformly distributed 32-bit value (Go `Uint32`)."""
        return UInt32(self._src.uint64() >> 32)

    def int32(mut self) -> Int32:
        """Returns a non-negative 31-bit value (Go `Int32`)."""
        return Int32(self._src.uint64() >> 33)

    def int_n(mut self, n: Int) -> Int:
        """Returns a value in [0, n) (Go `IntN`). Aborts if `n <= 0`, as Go
        panics."""
        if n <= 0:
            abort("invalid argument to IntN")
        return Int(self._uint64n(UInt64(n)))

    def float64(mut self) -> Float64:
        """Returns a value in [0, 1) (Go `Float64`)."""
        return Float64((self._src.uint64() << 11) >> 11) / Float64(1 << 53)

    def _uint64n(mut self, n: UInt64) -> UInt64:
        if n & (n - 1) == 0:
            return self._src.uint64() & (n - 1)
        var wide = UInt128(self._src.uint64()) * UInt128(n)
        var hi = UInt64(wide >> 64)
        var lo = UInt64(wide & 0xFFFFFFFFFFFFFFFF)
        if lo < n:
            var thresh = (0 - n) % n
            while lo < thresh:
                wide = UInt128(self._src.uint64()) * UInt128(n)
                hi = UInt64(wide >> 64)
                lo = UInt64(wide & 0xFFFFFFFFFFFFFFFF)
        return hi
