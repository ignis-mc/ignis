"""Bloom filters and filter blocks, ported from goleveldb `filter/bloom.go`,
`filter.go` and the filter parts of `table/writer.go` and `table/reader.go`.

Filters hash user keys. Tables written with filters name the policy
`leveldb.BuiltinBloomFilter2` in their metaindex, the name C++ LevelDB and
Mojang's fork look up (goleveldb calls the same format
`leveldb.BuiltinBloomFilter`; both names are read).

C++ LevelDB before 1.21 hashed tail bytes as signed `char`, so a filter
written by such a build (Mojang's fork may be one) disagrees with the
unsigned hash for keys whose trailing bytes are >= 0x80. Reading checks
both variants and only rules a key out when both do, which costs a few
extra false positives but never misses a key. Writing uses the unsigned
variant, as goleveldb and current C++ LevelDB do.
"""

from .util import get_u32, hash, hash_signed_tail, put_u32

comptime FILTER_NAME = "leveldb.BuiltinBloomFilter2"
"""The filter policy name written to the metaindex."""
comptime GO_FILTER_NAME = "leveldb.BuiltinBloomFilter"
"""The name goleveldb gives the same policy."""
comptime FILTER_BASE_LG = 11
"""A filter covers each 2 KiB of data block offsets (Go `filterBaseLg`)."""
comptime _SEED = UInt32(0xBC9F1D34)


def _bloom_contains(filter: Span[mut=False, UInt8, _], kh0: UInt32) -> Bool:
    var n_bytes = len(filter) - 1
    var n_bits = UInt32(n_bytes * 8)
    var k = filter[n_bytes]
    var kh = kh0
    var delta = (kh >> 17) | (kh << 15)
    for _ in range(Int(k)):
        var bitpos = kh % n_bits
        if UInt32(filter[Int(bitpos // 8)]) & (UInt32(1) << (bitpos % 8)) == 0:
            return False
        kh += delta
    return True


def bloom_may_contain(
    filter: Span[mut=False, UInt8, _], key: Span[mut=False, UInt8, _]
) -> Bool:
    """Reports whether a bloom filter may contain a key (Go
    `bloomFilter.Contains`, checking both hash variants).

    Args:
        filter: One filter: the bit array followed by the probe count.
        key: The user key.

    Returns:
        False only if the key is certainly absent.
    """
    if len(filter) - 1 < 1:
        return False
    if filter[len(filter) - 1] > 30:
        return True
    if _bloom_contains(filter, hash(key, _SEED)):
        return True
    return _bloom_contains(filter, hash_signed_tail(key, _SEED))


struct BloomGenerator(Movable, Sized):
    """Collects key hashes and builds one filter (Go
    `bloomFilterGenerator`)."""

    var _bits_per_key: Int
    var _k: UInt8
    var _hashes: List[UInt32]

    def __init__(out self, bits_per_key: Int):
        """Creates a generator.

        Args:
            bits_per_key: Filter bits per key (10 is LevelDB's usual choice).
        """
        self._bits_per_key = bits_per_key
        var k = bits_per_key * 69 // 100
        self._k = UInt8(max(1, min(30, k)))
        self._hashes = List[UInt32]()

    def __len__(self) -> Int:
        """Returns the number of keys added since the last filter.

        Returns:
            The key count.
        """
        return len(self._hashes)

    def add(mut self, key: Span[mut=False, UInt8, _]):
        """Adds a user key.

        Args:
            key: The key.
        """
        self._hashes.append(hash(key, _SEED))

    def generate(mut self, mut out: List[UInt8]):
        """Appends the filter of the keys added and forgets them.

        Args:
            out: The destination.
        """
        var n_bits = UInt32(len(self._hashes) * self._bits_per_key)
        if n_bits < 64:
            n_bits = 64
        var n_bytes = (n_bits + 7) // 8
        n_bits = n_bytes * 8
        var base = len(out)
        for _ in range(Int(n_bytes)):
            out.append(0)
        out.append(self._k)
        for h in self._hashes:
            var kh = h
            var delta = (kh >> 17) | (kh << 15)
            for _ in range(Int(self._k)):
                var bitpos = kh % n_bits
                out[base + Int(bitpos // 8)] |= UInt8(1) << UInt8(bitpos % 8)
                kh += delta
        self._hashes.clear()


struct FilterBlockWriter(Movable):
    """Builds a table's filter block (Go `filterWriter`)."""

    var _gen: BloomGenerator
    var _buf: List[UInt8]
    var _offsets: List[UInt32]

    def __init__(out self, bits_per_key: Int):
        """Creates a filter block writer.

        Args:
            bits_per_key: Filter bits per key.
        """
        self._gen = BloomGenerator(bits_per_key)
        self._buf = List[UInt8]()
        self._offsets = List[UInt32]()

    def add(mut self, ukey: Span[mut=False, UInt8, _]):
        """Adds the user key of an appended entry.

        Args:
            ukey: The user key.
        """
        self._gen.add(ukey)

    def _generate(mut self):
        self._offsets.append(UInt32(len(self._buf)))
        if len(self._gen) > 0:
            self._gen.generate(self._buf)

    def flush(mut self, offset: Int):
        """Starts filters up to the data block that begins at `offset`.

        Args:
            offset: The file offset of the next data block.
        """
        while offset // (1 << FILTER_BASE_LG) > len(self._offsets):
            self._generate()

    def finish(mut self) -> List[UInt8]:
        """Finishes the block: filters, their offsets, the offset of the
        offsets and the base log.

        Returns:
            The filter block.
        """
        if len(self._gen) > 0:
            self._generate()
        self._offsets.append(UInt32(len(self._buf)))
        for o in self._offsets:
            put_u32(self._buf, o)
        self._buf.append(FILTER_BASE_LG)
        var out = self._buf^
        self._buf = List[UInt8]()
        return out^


struct FilterBlockReader(Copyable, Movable):
    """Answers filter queries for a table (Go `filterBlock`)."""

    var _data: List[UInt8]
    var _o_offset: Int
    var _base_lg: Int
    var _filters: Int

    def __init__(out self, var data: List[UInt8]) raises:
        """Parses a filter block.

        Args:
            data: The block.

        Raises:
            If the block is malformed.
        """
        if len(data) < 5:
            raise Error("leveldb: filter block too short")
        var base_lg = Int(data[len(data) - 1])
        var o_offset = Int(get_u32(Span(data), len(data) - 5))
        if o_offset > len(data) - 5:
            raise Error("leveldb: invalid filter block offsets")
        self._filters = (len(data) - 5 - o_offset) // 4
        self._o_offset = o_offset
        self._base_lg = base_lg
        self._data = data^

    def may_contain(
        self, block_offset: Int, ukey: Span[mut=False, UInt8, _]
    ) -> Bool:
        """Reports whether the data block at `block_offset` may hold a key.

        Args:
            block_offset: The file offset of the data block.
            ukey: The user key.

        Returns:
            False only if the key is certainly absent from that block.
        """
        var i = block_offset >> self._base_lg
        if i < self._filters:
            var d = Span(self._data)
            var n = Int(get_u32(d, self._o_offset + i * 4))
            var m = Int(get_u32(d, self._o_offset + i * 4 + 4))
            if n < m and m <= self._o_offset:
                return bloom_may_contain(d[n:m], ukey)
            elif n == m:
                return False
        return True
