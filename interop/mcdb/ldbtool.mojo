"""The Mojo side of the LevelDB interop checks (see `run.sh`).

    ldbtool write <dir> <seed> <n> [unclean]
    ldbtool dump <dir> <out.txt>

`write` runs the same workload as `ldb.go` against `ignis.leveldb`; with
`unclean` it aborts the process right after the last write. `dump` writes
every key and value as hex, one pair per line, sorted.
"""

from ignis.internal.fs import write_file
from ignis.leveldb.batch import Batch
from ignis.leveldb.db import DB
from ignis.leveldb.options import KIB, Options
from std.os import abort
from std.sys import argv


struct Rng:
    var s: UInt64

    def __init__(out self, seed: UInt64):
        self.s = seed

    def next(mut self) -> UInt64:
        self.s ^= self.s << 13
        self.s ^= self.s >> 7
        self.s ^= self.s << 17
        return self.s


def _pad5(n: Int) -> String:
    var s = String(n)
    while s.byte_length() < 5:
        s = "0" + s
    return s^


def _put_u32(mut out: List[UInt8], x: UInt32):
    for i in range(4):
        out.append(UInt8((x >> UInt32(8 * i)) & 0xFF))


def gen_batches(seed: UInt64, n: Int) -> List[Batch]:
    var r = Rng(seed)
    var out = List[Batch]()
    var i = 0
    while i < n:
        var size = 1 + Int(r.next() % 5)
        var b = Batch()
        var j = 0
        while j < size and i < n:
            var x = r.next()
            var k = Int(x % 2000)
            var key = List[UInt8]()
            var kind = (x >> 11) % 3
            if kind == 0:
                key = List[UInt8](String("key-", _pad5(k)).as_bytes())
            elif kind == 1:
                _put_u32(key, UInt32(Int32(k) - 1000))
                _put_u32(key, UInt32(Int32(k % 37) - 18))
                key.append(0x2F)
                key.append(UInt8(Int8(k % 24) - 4))
            else:
                key = List[UInt8](String("player_", k).as_bytes())
            j += 1
            i += 1
            if (x >> 20) % 10 >= 8:
                b.delete(Span(key))
                continue
            var vlen = Int(r.next() % 3000)
            if (x >> 30) % 50 == 0:
                vlen = 40000
            var base = r.next()
            var v = List[UInt8](capacity=vlen)
            for t in range(vlen):
                v.append(
                    UInt8((base >> UInt64((t % 8) * 8)) & 0xFF)
                    ^ UInt8((t // 16) & 0xFF)
                )
            b.put(Span(key), Span(v))
        out.append(b^)
    var last = Batch()
    last.put("last-key".as_bytes(), "last-value".as_bytes())
    out.append(last^)
    return out^


def options() -> Options:
    var o = Options()
    o.block_size = 16 * KIB
    o.write_buffer = 64 * KIB
    o.compaction_table_size = 32 * KIB
    o.compaction_total_size = 128 * KIB
    return o^


comptime _HEX = "0123456789abcdef"


def _hex(mut out: List[UInt8], b: Span[UInt8, _]):
    var h = _HEX.as_bytes()
    for c in b:
        out.append(h[Int(c >> 4)])
        out.append(h[Int(c & 15)])


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error("usage: ldbtool write|dump ...")
    var cmd = String(args[1])
    if cmd == "write":
        var db = DB(String(args[2]), options())
        for b in gen_batches(
            UInt64(Int(String(args[3]))), Int(String(args[4]))
        ):
            db.write(b)
        if len(args) > 5 and String(args[5]) == "unclean":
            abort("unclean stop")
        _ = db^
    elif cmd == "dump":
        var db = DB(String(args[2]), options())
        var it = db.new_iterator()
        var out = List[UInt8]()
        while it.next():
            _hex(out, it.key())
            out.append(UInt8(ord("\t")))
            _hex(out, it.value())
            out.append(UInt8(ord("\n")))
            var got = db.get(it.key())
            if not got or got.value() != List[UInt8](it.value()):
                raise Error("get disagrees with the iterator")
        write_file(String(args[3]), Span(out), sync=False)
    else:
        raise Error("unknown command")
