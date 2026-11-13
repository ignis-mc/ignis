"""The Mojo side of the LevelDB interop checks (see `run_leveldb.sh`).

    ldbtool write <dir> <seed> <n> [unclean]
    ldbtool dump <dir> <out.txt>

`write` runs the same workload as `ldb.go` against `ignis.leveldb`; with
`unclean` it aborts the process right after the last write. `dump` writes
every key and value as hex, one pair per line, sorted.
"""

from ignis.internal.fs import write_file
from ignis.leveldb.db import DB
from std.os import abort
from std.sys import argv
from support.ldb_workload import gen_batches, options


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
