"""The Mojo side of the world interop checks (see `run_world.sh`).

    worldtool write <dir>
    worldtool dump <dir> <out.txt> [lenient]

`write` stores the fixture world of `world.go` with `ignis.world.mcdb`;
`dump` writes what the provider loads in `world.go`'s dump format.
"""

from ignis.block.register import vanilla_block_registry
from ignis.internal.fs import write_file
from ignis.world.mcdb.db import DB
from std.memory import ArcPointer
from std.sys import argv
from support.mcdb_world import dump, write_fixture


def main() raises:
    var args = argv()
    var br = ArcPointer(vanilla_block_registry())
    var cmd = String(args[1])
    if cmd == "write":
        write_fixture(String(args[2]), br)
    elif cmd == "dump":
        var db = DB.open(String(args[2]), br)
        var lenient = len(args) > 4 and String(args[4]) == "lenient"
        write_file(String(args[3]), dump(db, lenient).as_bytes(), sync=False)
        db.close()
    else:
        raise Error("usage: worldtool write|dump ...")
