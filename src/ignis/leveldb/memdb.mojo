"""The memtable: a skip list of internal keys over one byte arena, ported
from goleveldb `memdb/memdb.go`.

Nodes live in one `List[Int]`: key-value offset, key length, value length,
height, then `height` next-node indices. Node 0 is the head.
"""

from .key import compare_internal

comptime _MAX_HEIGHT = 12
comptime _BRANCHING = 4
comptime _N_KV = 0
comptime _N_KEY = 1
comptime _N_VAL = 2
comptime _N_HEIGHT = 3
comptime _N_NEXT = 4


struct MemDB(Copyable, Movable, Sized):
    """An in-memory sorted map of internal keys to values (Go `memdb.DB`)."""

    var _kv: List[UInt8]
    var _nodes: List[Int]
    var _prev: List[Int]
    var _max_height: Int
    var _n: Int
    var _kv_size: Int
    var _rnd: UInt64

    def __init__(out self, capacity: Int = 0):
        """Creates an empty memtable."""
        self._kv = List[UInt8](capacity=capacity)
        self._nodes = List[Int](capacity=4 + _MAX_HEIGHT)
        for _ in range(4):
            self._nodes.append(0)
        self._nodes[_N_HEIGHT] = _MAX_HEIGHT
        for _ in range(_MAX_HEIGHT):
            self._nodes.append(0)
        self._prev = List[Int](length=_MAX_HEIGHT, fill=0)
        self._max_height = 1
        self._n = 0
        self._kv_size = 0
        self._rnd = 0xDEADBEEF

    def __len__(self) -> Int:
        """Returns the number of entries."""
        return self._n

    def size(self) -> Int:
        """Returns the bytes of keys and values held (Go `DB.Size`)."""
        return self._kv_size

    def _rand_height(mut self) -> Int:
        var h = 1
        while h < _MAX_HEIGHT:
            # xorshift64*
            self._rnd ^= self._rnd >> 12
            self._rnd ^= self._rnd << 25
            self._rnd ^= self._rnd >> 27
            var r = self._rnd * 0x2545F4914F6CDD1D
            if (r >> 32) % _BRANCHING != 0:
                break
            h += 1
        return h

    def key_at(self, node: Int) -> Span[UInt8, origin_of(self._kv)]:
        """Returns the internal key of a node."""
        var o = self._nodes[node + _N_KV]
        return Span(self._kv)[o : o + self._nodes[node + _N_KEY]]

    def value_at(self, node: Int) -> Span[UInt8, origin_of(self._kv)]:
        """Returns the value of a node."""
        var o = self._nodes[node + _N_KV] + self._nodes[node + _N_KEY]
        return Span(self._kv)[o : o + self._nodes[node + _N_VAL]]

    def _find_ge(mut self, key: Span[mut=False, UInt8, _]) -> Tuple[Int, Bool]:
        var node = 0
        var h = self._max_height - 1
        while True:
            var next = self._nodes[node + _N_NEXT + h]
            var cmp = 1
            if next != 0:
                cmp = compare_internal(self.key_at(next), key)
            if cmp < 0:
                node = next
            else:
                self._prev[h] = node
                if h == 0:
                    return (next, cmp == 0)
                h -= 1

    def find_ge(self, key: Span[mut=False, UInt8, _]) -> Int:
        """Finds the first node whose key is not less than `key`."""
        var node = 0
        var h = self._max_height - 1
        while True:
            var next = self._nodes[node + _N_NEXT + h]
            var cmp = 1
            if next != 0:
                cmp = compare_internal(self.key_at(next), key)
            if cmp < 0:
                node = next
            else:
                if h == 0:
                    return next
                h -= 1

    def first(self) -> Int:
        """Returns the first node."""
        return self._nodes[_N_NEXT]

    def next(self, node: Int) -> Int:
        """Returns the node after `node`."""
        return self._nodes[node + _N_NEXT]

    def put(
        mut self,
        key: Span[mut=False, UInt8, _],
        value: Span[mut=False, UInt8, _],
    ):
        """Inserts an entry, replacing the value of an identical key (Go
        `DB.Put`)."""
        var found = self._find_ge(key)
        if found[1]:
            var node = found[0]
            var kv_offset = len(self._kv)
            self._kv.extend(key)
            self._kv.extend(value)
            self._nodes[node + _N_KV] = kv_offset
            var old = self._nodes[node + _N_VAL]
            self._nodes[node + _N_VAL] = len(value)
            self._kv_size += len(value) - old
            return
        var h = self._rand_height()
        if h > self._max_height:
            for i in range(self._max_height, h):
                self._prev[i] = 0
            self._max_height = h
        var kv_offset = len(self._kv)
        self._kv.extend(key)
        self._kv.extend(value)
        var node = len(self._nodes)
        self._nodes.append(kv_offset)
        self._nodes.append(len(key))
        self._nodes.append(len(value))
        self._nodes.append(h)
        for i in range(h):
            var m = self._prev[i] + _N_NEXT + i
            self._nodes.append(self._nodes[m])
            self._nodes[m] = node
        self._kv_size += len(key) + len(value)
        self._n += 1
