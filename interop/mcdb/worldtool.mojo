"""The Mojo side of the world interop checks (see `run_world.sh`).

    worldtool write <dir>
    worldtool dump <dir> <out.txt> [lenient]
    worldtool tower <dir> <chunk x> <chunk z> <name>

`tower` loads an overworld column, builds a 3x3 gold tower from y 60 to
y 150 in its middle, stores it, rewrites every table (`compact_all`) and
renames the world, to check that a vanilla client opens a world Ignis
wrote.

`write` stores the fixture world of `world.go` with `ignis.world.mcdb`;
`dump` writes what the provider loads in `world.go`'s dump format.
"""

from ignis.block.register import vanilla_block_registry
from ignis.internal.fs import write_file
from ignis.world.block_state import Properties
from ignis.world.dimension import OVERWORLD
from ignis.world.mcdb.db import DB
from ignis.world.position import ChunkPos
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
    elif cmd == "tower":
        var db = DB.open(String(args[2]), br)
        var pos = ChunkPos(
            Int32(Int(String(args[3]))), Int32(Int(String(args[4])))
        )
        var col = db.load_column(pos, OVERWORLD).value().copy()
        var gold = (
            br[].block_by_name("minecraft:gold_block", Properties()).value()
        )
        for x in range(7, 10):
            for z in range(7, 10):
                for y in range(60, 151):
                    col.chunk.set_block(UInt8(x), Int16(y), UInt8(z), 0, gold)
        db.store_column(pos, OVERWORLD, col^)
        db.level_data().level_name = String(args[5])
        db.ldb().compact_all()
        db.close()
    else:
        raise Error("usage: worldtool write|dump|tower ...")
