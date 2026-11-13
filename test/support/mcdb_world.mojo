"""The fixture world of `interop/mcdb/world.go`, rebuilt in Mojo, and the
dump format both sides compare."""

from std.memory import ArcPointer, bitcast

from ignis.block.cube.pos import Pos
from ignis.block.dirt import Dirt
from ignis.block.stone import Stone
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.chunk.chunk import Chunk
from ignis.world.chunk.column import (
    BlockEntity,
    Column,
    Entity,
    ScheduledBlockUpdate,
)
from ignis.world.chunk.paletted_storage import PalettedStorage
from ignis.world.difficulty import DIFFICULTY_HARD
from ignis.world.dimension import END, NETHER, OVERWORLD, Dimension
from ignis.world.game_mode import GAME_MODE_CREATIVE
from ignis.world.mcdb.db import DB
from ignis.world.mcdb.iterator import ColumnIterator, IteratorRange
from ignis.world.position import ChunkPos
from minecraft.nbt.nbt import (
    TAG_BYTE,
    TAG_COMPOUND,
    TAG_DOUBLE,
    TAG_FLOAT,
    TAG_INT,
    TAG_LIST,
    TAG_LONG,
    TAG_SHORT,
    TAG_STRING,
)
from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID
from nethernet.crypto.sha256 import sha256
from nethernet.wire import hex_encode
from support.world_vectors import (
    biome_chunk,
    flat_chunk,
    mixed_chunk,
    rids,
    simple_chunk,
)

comptime FIXTURE_PLAYER = "8f9a6c2e-1b3d-4e5f-a6b7-c8d9e0f1a2b3"
"""The player whose spawn position the fixture stores."""


def nether_chunk(br: BasicBlockRegistry) -> Chunk:
    """Go `netherChunk`."""
    var c = Chunk(br, NETHER.range())
    var values = rids(br, 5)
    for x in range(16):
        for z in range(16):
            var h = 10 + (x + z) % 40
            for y in range(h + 1):
                c.set_block(
                    UInt8(x), Int16(y), UInt8(z), 0, values[(x + y + z) % 5]
                )
    return c^


def end_chunk(br: BasicBlockRegistry) -> Chunk:
    """Go `endChunk`."""
    var c = Chunk(br, END.range())
    var values = rids(br, 3)
    for x in range(16):
        c.set_block(UInt8(x), 60, 0, 0, values[0])
        c.set_block(UInt8(x), 60, 15, 0, values[1])
        c.set_block(0, 60, UInt8(x), 0, values[2])
    return c^


@fieldwise_init
struct FixtureColumn(Copyable):
    """A column of the fixture world with its position."""

    var pos: ChunkPos
    var dim: Dimension
    var col: Column


def fixture_columns(br: BasicBlockRegistry) raises -> List[FixtureColumn]:
    """Go `fixtureColumns`."""
    var stone = br.block_runtime_id(Stone())
    var dirt = br.block_runtime_id(Dirt())

    var mixed = Column(mixed_chunk(br))
    var pig = Tree()
    var r = pig.root()
    _ = pig.put_string(r, "identifier", "minecraft:pig")
    var p = pig.put_list(r, "Pos", TAG_FLOAT)
    _ = pig.append_float(p, 1.5)
    _ = pig.append_float(p, 70)
    _ = pig.append_float(p, -2.25)
    var rot = pig.put_list(r, "Rotation", TAG_FLOAT)
    _ = pig.append_float(rot, 90)
    _ = pig.append_float(rot, 0)
    _ = pig.put_short(r, "Health", 10)
    _ = pig.put_byte(r, "Saddled", 1)
    var defs = pig.put_list(r, "definitions", TAG_STRING)
    _ = pig.append_string(defs, "+minecraft:pig")
    _ = pig.append_string(defs, "+minecraft:pig_adult")
    mixed.entities.append(Entity(-4294967295, pig^))
    var item = Tree()
    r = item.root()
    _ = item.put_string(r, "identifier", "minecraft:item")
    p = item.put_list(r, "Pos", TAG_FLOAT)
    _ = item.append_float(p, 3)
    _ = item.append_float(p, 64.5)
    _ = item.append_float(p, 3)
    _ = item.put_int(r, "Age", 1200)
    var it = item.put_compound(r, "Item")
    _ = item.put_string(it, "Name", "minecraft:diamond")
    _ = item.put_byte(it, "Count", 3)
    _ = item.put_short(it, "Damage", 0)
    mixed.entities.append(Entity(77, item^))

    var simple = Column(simple_chunk(br))
    var chest = Tree()
    r = chest.root()
    _ = chest.put_string(r, "id", "Chest")
    _ = chest.put_string(r, "CustomName", "Fixture chest")
    var items = chest.put_list(r, "Items", TAG_COMPOUND)
    var slot = chest.append_compound(items)
    _ = chest.put_string(slot, "Name", "minecraft:stone")
    _ = chest.put_byte(slot, "Count", 64)
    _ = chest.put_byte(slot, "Slot", 0)
    _ = chest.put_byte(r, "Findable", 0)
    simple.block_entities.append(BlockEntity(Pos(-16 + 2, 5, 32 + 3), chest^))
    var sign = Tree()
    _ = sign.put_string(sign.root(), "id", "Sign")
    _ = sign.put_string(sign.root(), "Text", "hello")
    simple.block_entities.append(BlockEntity(Pos(-16 + 9, -60, 32 + 15), sign^))

    var biomes = Column(biome_chunk(br))
    biomes.tick = 1234
    biomes.scheduled_blocks.append(
        ScheduledBlockUpdate(Pos(80, 10, -112), stone, 1240)
    )
    biomes.scheduled_blocks.append(
        ScheduledBlockUpdate(Pos(81, -64, -100), dirt, 1300)
    )

    var out = List[FixtureColumn]()
    out.append(FixtureColumn(ChunkPos(0, 0), OVERWORLD, mixed^))
    out.append(FixtureColumn(ChunkPos(-1, 2), OVERWORLD, simple^))
    out.append(FixtureColumn(ChunkPos(5, -7), OVERWORLD, biomes^))
    out.append(FixtureColumn(ChunkPos(1, 1), OVERWORLD, Column(flat_chunk(br))))
    out.append(FixtureColumn(ChunkPos(0, 0), NETHER, Column(nether_chunk(br))))
    out.append(FixtureColumn(ChunkPos(-3, -3), END, Column(end_chunk(br))))
    return out^


def write_fixture(dir: StringSlice, br: ArcPointer[BasicBlockRegistry]) raises:
    """Go `worldWrite`."""
    var db = DB.open(dir, br)
    var s = db.settings().value().copy()
    s.name = "Ignis Fixture"
    s.spawn = Pos(1, 70, 2)
    s.time = 6000
    s.time_cycle = False
    s.rain_time = 12000
    s.raining = True
    s.thunder_time = 24000
    s.current_tick = 99999
    s.default_game_mode = GAME_MODE_CREATIVE
    s.difficulty = DIFFICULTY_HARD
    s.tick_range = 4
    db.save_settings(s)
    for c in fixture_columns(br[]):
        db.store_column(c.pos, c.dim, c.col.copy())
    db.save_player_spawn_position(UUID.parse(FIXTURE_PLAYER), Pos(-5, 64, 9))
    db.close()


def _quote(s: String) -> String:
    # Go %q (strconv.Quote) for ASCII and control characters.
    var out = String('"')
    for cp in s.codepoint_slices():
        var b = cp.as_bytes()
        var c = Int(b[0]) if len(b) == 1 else 0x100
        if cp == '"' or cp == "\\":
            out += "\\" + String(cp)
        elif c == 7:
            out += "\\a"
        elif c == 8:
            out += "\\b"
        elif c == 12:
            out += "\\f"
        elif c == 10:
            out += "\\n"
        elif c == 13:
            out += "\\r"
        elif c == 9:
            out += "\\t"
        elif c == 11:
            out += "\\v"
        elif c < 0x20 or c == 0x7F:
            out += "\\x" + _hex(UInt64(c), 2)
        else:
            out += cp
    return out + '"'


def _hex(v: UInt64, digits: Int) -> String:
    comptime h = "0123456789abcdef"
    var out = String()
    for i in range(digits - 1, -1, -1):
        out += String(h[byte=Int((v >> UInt64(4 * i)) & 15)])
    return out^


def canon(t: Tree, e: Tag) raises -> String:
    """Go `canon`: sorted compound keys, typed scalars."""
    var ty = t.type_of(e)
    if ty == TAG_BYTE:
        return String(t.as_byte(e), "b")
    if ty == TAG_SHORT:
        return String(t.as_short(e), "s")
    if ty == TAG_INT:
        return String(t.as_int(e), "i")
    if ty == TAG_LONG:
        return String(t.as_long(e), "l")
    if ty == TAG_FLOAT:
        return "f" + _hex(UInt64(bitcast[DType.uint32](t.as_float(e))), 8)
    if ty == TAG_DOUBLE:
        return "d" + _hex(bitcast[DType.uint64](t.as_double(e)), 16)
    if ty == TAG_STRING:
        return _quote(t.as_string(e))
    if ty == TAG_LIST:
        var out = String("[")
        var first = True
        for c in t.children(e):
            if not first:
                out += ","
            first = False
            out += canon(t, c)
        return out + "]"
    if ty == TAG_COMPOUND:
        var names = List[String]()
        for c in t.children(e):
            names.append(t.name(c))
        sort(names)
        var out = String("{")
        for i in range(len(names)):
            if i > 0:
                out += ","
            out += _quote(names[i]) + ":" + canon(t, t.get(e, names[i]).value())
        return out + "}"
    return String("?", ty)


def _storage_hash(s: PalettedStorage) -> String:
    var b = List[UInt8](capacity=4096 * 4)
    for x in range(16):
        for y in range(16):
            for z in range(16):
                var v = s.at(UInt8(x), UInt8(y), UInt8(z))
                b.append(UInt8(v & 0xFF))
                b.append(UInt8((v >> 8) & 0xFF))
                b.append(UInt8((v >> 16) & 0xFF))
                b.append(UInt8(v >> 24))
    return String(hex_encode(Span(sha256(Span(b))))[byte=0:16])


def _b(v: Bool) -> String:
    return "true" if v else "false"


def _pos(p: Pos) -> String:
    return String("[", p.x(), " ", p.y(), " ", p.z(), "]")


def _pad2(i: Int) -> String:
    return String("0", i) if i < 10 else String(i)


def _column_keys(db: DB) raises -> List[Tuple[Dimension, ChunkPos]]:
    # Go columnKeys: the version keys of every column.
    var out = List[Tuple[Dimension, ChunkPos]]()
    var seen = List[String]()
    var it = db.ldb().new_iterator()
    while it.next():
        var k = it.key()
        var n = len(k)
        if (n != 9 and n != 13) or (k[n - 1] != 0x2C and k[n - 1] != 0x76):
            continue
        var id = 0
        if n > 9:
            id = (
                Int(k[8])
                | (Int(k[9]) << 8)
                | (Int(k[10]) << 16)
                | (Int(k[11]) << 24)
            )
        var x = Int32(
            UInt32(k[0])
            | (UInt32(k[1]) << 8)
            | (UInt32(k[2]) << 16)
            | (UInt32(k[3]) << 24)
        )
        var z = Int32(
            UInt32(k[4])
            | (UInt32(k[5]) << 8)
            | (UInt32(k[6]) << 16)
            | (UInt32(k[7]) << 24)
        )
        var key = String(id, " ", x, " ", z)
        if key in seen:
            continue
        seen.append(key)
        var dim = OVERWORLD if id == 0 else (NETHER if id == 1 else END)
        out.append((dim, ChunkPos(x, z)))
    return out^


def dump(mut db: DB, lenient: Bool = False) raises -> String:
    """Go `worldDump`: everything the provider returns, one fact per line.
    With `lenient`, each column loads on its own and failures are ERR."""
    var s = db.settings().value().copy()
    var out = String(
        "settings ",
        _quote(s.name),
        " spawn=",
        _pos(s.spawn),
        " time=",
        s.time,
        " cycle=",
        _b(s.time_cycle),
        " rain=",
        s.rain_time,
        " raining=",
        _b(s.raining),
        " thunder=",
        s.thunder_time,
        " thundering=",
        _b(s.thundering),
        " weather=",
        _b(s.weather_cycle),
        " tick=",
        s.current_tick,
        " mode=",
        s.default_game_mode.id,
        " difficulty=",
        s.difficulty.id,
        " range=",
        s.tick_range,
        "\n",
    )
    var sp = db.load_player_spawn_position(UUID.parse(FIXTURE_PLAYER))
    if case .Some(p) = sp:
        out += String("player ", _pos(p), " true <nil>\n")
    else:
        out += "player [0 0 0] false <nil>\n"
    var lines = List[String]()
    if lenient:
        for k in _column_keys(db):
            var p = String(k[0].id, " ", k[1].x(), " ", k[1].z())
            try:
                var col = db.read_column(k[1], k[0])
                _column_lines(p, col.value(), lines)
            except:
                lines.append(p + " ERR")
    else:
        var it = ColumnIterator(db, IteratorRange())
        while it.next(db):
            var cp = it.position()
            var p = String(it.dimension().id, " ", cp.x(), " ", cp.z())
            _column_lines(p, it.column().value(), lines)
    sort(lines)
    for l in lines:
        out += l
        out += "\n"
    return out^


def _column_lines(p: String, col: Column, mut lines: List[String]) raises:
    if True:
        ref c = col.chunk
        for i in range(len(c.sub())):
            ref layers = c.sub()[i].layers()
            var line = String(
                p, " sub ", _pad2(i), " layers=", len(layers), " "
            )
            for j in range(len(layers)):
                if j > 0:
                    line += " "
                line += _storage_hash(layers[j])
            lines.append(line^)
        var bb = List[UInt8]()
        var r = c.range()
        for y in range(r.min(), r.max() + 1):
            for x in range(16):
                for z in range(16):
                    var v = c.biome(UInt8(x), Int16(y), UInt8(z))
                    bb.append(UInt8(v & 0xFF))
                    bb.append(UInt8((v >> 8) & 0xFF))
                    bb.append(UInt8((v >> 16) & 0xFF))
                    bb.append(UInt8(v >> 24))
        lines.append(
            String(
                p,
                " biomes ",
                String(hex_encode(Span(sha256(Span(bb))))[byte=0:16]),
            )
        )
        lines.append(String(p, " legacy ", _b(c.legacy_states())))
        for ref e in col.entities:
            lines.append(
                String(p, " entity ", e.id, " ", canon(e.data, e.data.root()))
            )
        for ref be in col.block_entities:
            lines.append(
                String(
                    p,
                    " blockentity ",
                    _pos(be.pos),
                    " ",
                    canon(be.data, be.data.root()),
                )
            )
        lines.append(String(p, " tick ", col.tick))
        for ref u in col.scheduled_blocks:
            lines.append(
                String(p, " scheduled ", _pos(u.pos), " ", u.block, " ", u.tick)
            )
