"""The world provider for the vanilla world format, ported from Dragonfly
`server/world/mcdb/db.go`.

It implements the method set of Dragonfly's `world.Provider` (`settings`,
`save_settings`, `load_player_spawn_position`,
`save_player_spawn_position`, `load_column`, `store_column`, `close`) with
the signatures of `ignis.world.provider.Provider`.

Differences from Go:

- A missing column is None instead of `leveldb.ErrNotFound`.
- A scheduled update whose block state cannot be decoded is skipped; Go
  logs it and leaves a zero entry (air at 0,0,0) in the list.
- Entity data that fails to decode raises; Go logs it and keeps an empty
  entity.
- Go's `Log.Debug` for unsupported chunk versions is dropped.
"""

from std.memory import ArcPointer

from minecraft.nbt.decode import decode, decode_from
from minecraft.nbt.encode import encode, encode_to
from minecraft.nbt.nbt import (
    LITTLE_ENDIAN,
    TAG_COMPOUND,
    TAG_INT,
    TAG_LONG,
    TAG_STRING,
)
from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID
from nethernet.os.time import unix_time_s

from ...block.cube.pos import Pos
from ...block.cube.range import Range
from ...internal.fs import exists, join, make_dir_all, write_file
from ...leveldb.batch import Batch
from ...leveldb.db import DB as LevelDB
from ...leveldb.options import Options
from ..block_registry import BasicBlockRegistry
from ..chunk.column import BlockEntity, Column, Entity, ScheduledBlockUpdate
from ..chunk.conversion import Upgrades
from ..chunk.decode import disk_decode
from ..chunk.encode import SerialisedData, disk_encode
from ..chunk.encoding import decode_disk_block_state, encode_disk_block_state
from ..dimension import Dimension
from ..provider import Provider
from ..position import ChunkPos
from ..settings import Settings
from .keys import (
    FINALISATION_POPULATED,
    KEY_3D_DATA,
    KEY_BLOCK_ENTITIES,
    KEY_ENTITIES_OLD,
    KEY_ENTITY,
    KEY_ENTITY_IDENTIFIERS,
    KEY_FINALISATION,
    KEY_LEGACY_STATES,
    KEY_PENDING_SCHEDULED_TICKS,
    KEY_SUB_CHUNK_DATA,
    KEY_VERSION,
    KEY_VERSION_OLD,
)
from .leveldat.data import Data
from .leveldat.level_dat import LevelDat
from .leveldat.version import VERSION

comptime CHUNK_VERSION: UInt8 = 42
"""The chunk version written (Go `chunkVersion`)."""


def index(pos: ChunkPos, dim: Dimension) -> List[UInt8]:
    """Returns the key prefix of a chunk (Go `index`): X and Z as
    little-endian int32, then the dimension ID unless it is the overworld."""
    var b = List[UInt8](capacity=13)
    _put_u32(b, UInt32(pos.x()))
    _put_u32(b, UInt32(pos.z()))
    if dim.id != 0:
        _put_u32(b, UInt32(dim.id))
    return b^


def _key(pos: ChunkPos, dim: Dimension, tag: UInt8) -> List[UInt8]:
    var k = index(pos, dim)
    k.append(tag)
    return k^


def _put_u32(mut b: List[UInt8], v: UInt32):
    for i in range(4):
        b.append(UInt8((v >> UInt32(8 * i)) & 0xFF))


def _put_u64(mut b: List[UInt8], v: UInt64):
    for i in range(8):
        b.append(UInt8((v >> UInt64(8 * i)) & 0xFF))


def _get_u64(b: Span[UInt8, _], o: Int) -> UInt64:
    var x = UInt64(0)
    for i in range(8):
        x |= UInt64(b[o + i]) << UInt64(8 * i)
    return x


def entity_index(id: Int64) -> List[UInt8]:
    """Returns the key of an entity's data (Go `entityIndex`)."""
    var k = List[UInt8](KEY_ENTITY.as_bytes())
    _put_u64(k, UInt64(id))
    return k^


def _block_pos_from_nbt(t: Tree, c: Tag) raises -> Pos:
    # Go blockPosFromNBT: missing or non-int components are 0.
    var xyz = List[Int]()
    for k in ["x", "y", "z"]:
        var v = 0
        if case .Some(e) = t.get(c, k):
            if t.type_of(e) == TAG_INT:
                v = Int(t.as_int(e))
        xyz.append(v)
    return Pos(xyz[0], xyz[1], xyz[2])


struct DB(Movable, Provider):
    """A world in the vanilla Bedrock format (Go `mcdb.DB`)."""

    var _ldb: LevelDB
    var _dir: String
    var _ldat: Data
    var _set: Settings
    var _blocks: ArcPointer[BasicBlockRegistry]
    var _upgrades: Upgrades

    def __init__(
        out self,
        dir: StringSlice,
        var opts: Options,
        blocks: ArcPointer[BasicBlockRegistry],
    ) raises:
        """Opens or creates a world (Go `Config.Open`); prefer
        `Config.open`."""
        var d = String(dir)
        make_dir_all(join(d, "db"))
        var ldat = Data()
        var path = join(d, "level.dat")
        if not exists(path):
            ldat.fill_default()
        else:
            var l = LevelDat.read_file(path)
            var ver = l.ver()
            if ver != Int(VERSION) and ver >= 10:
                raise Error(t"open db: level.dat version {ver} is unsupported")
            try:
                ldat = l.unmarshal()
            except e:
                raise Error(t"open db: unmarshal level.dat: {e}")
        var set = ldat.settings()
        var upgrades = Upgrades.load()
        var ldb = LevelDB(join(d, "db"), opts^)
        self._ldb = ldb^
        self._dir = d^
        self._ldat = ldat^
        self._set = set^
        self._blocks = blocks
        self._upgrades = upgrades^

    @staticmethod
    def open(
        dir: StringSlice, blocks: ArcPointer[BasicBlockRegistry]
    ) raises -> DB:
        """Opens or creates a world with default options (Go `Open`)."""
        from .conf import Config

        return Config(blocks).open(dir)

    def ldb(ref self) -> ref[self._ldb] LevelDB:
        """Returns the underlying LevelDB."""
        return self._ldb

    def level_data(ref self) -> ref[self._ldat] Data:
        """Returns the `level.dat` fields that `close` will write."""
        return self._ldat

    # ===------------------------------------------------------------------=== #
    # Settings and players
    # ===------------------------------------------------------------------=== #

    def settings(mut self) -> Optional[Settings]:
        """Returns the settings read from `level.dat` (Go `Settings`)."""
        return self._set.copy()

    def save_settings(mut self, s: Settings) raises:
        """Stores settings in the `level.dat` written by `close` (Go
        `SaveSettings`)."""
        self._ldat.put_settings(s)
        self._set = s.copy()

    def _load_player_data(
        self, id: UUID
    ) raises -> Optional[Tuple[Tree, String]]:
        # Go loadPlayerData: player_<uuid> names the server data key.
        var uid = String(id)
        var data = self._ldb.get(String("player_", uid).as_bytes())
        if not data:
            return None
        var t = decode(Span(data.value()), LITTLE_ENDIAN)
        var root = t.root()
        var msa = String()
        var server_id = String()
        if case .Some(e) = t.get(root, "MsaId"):
            msa = t.as_string(e)
        if case .Some(e) = t.get(root, "ServerId"):
            server_id = t.as_string(e)
        if msa != uid or server_id == "":
            raise Error(t"invalid player data for uuid {uid}")
        var server = self._ldb.get(server_id.as_bytes())
        if not server:
            raise Error(
                t"error reading server data for player {uid} ({server_id}): not"
                t" found"
            )
        var st = decode(Span(server.value()), LITTLE_ENDIAN)
        return (st^, server_id^)

    def load_player_spawn_position(mut self, id: UUID) raises -> Optional[Pos]:
        """Loads a player's spawn position (Go `LoadPlayerSpawnPosition`)."""
        var r = self._load_player_data(id)
        if not r:
            return None
        ref t = r.value()[0]
        var root = t.root()
        var x = t.get(root, "SpawnX")
        var y = t.get(root, "SpawnY")
        var z = t.get(root, "SpawnZ")
        if not x or not y or not z:
            raise Error(
                t"error reading spawn fields from server data for player {id}"
            )
        return Pos(
            Int(t.as_int(x.value())),
            Int(t.as_int(y.value())),
            Int(t.as_int(z.value())),
        )

    def save_player_spawn_position(mut self, id: UUID, pos: Pos) raises:
        """Saves a player's spawn position (Go `SavePlayerSpawnPosition`)."""
        var uid = String(id)
        var server = Tree()
        var k = String("player_server_", uid)
        if not self._ldb.get(String("player_", uid).as_bytes()):
            var pd = Tree()
            _ = pd.put_string(pd.root(), "MsaId", uid)
            _ = pd.put_string(pd.root(), "ServerId", k)
            _ = pd.put_string(pd.root(), "SelfSignedId", "")
            self._ldb.put(
                String("player_", uid).as_bytes(),
                Span(encode(pd, LITTLE_ENDIAN)),
            )
        elif case .Some(r) = self._load_player_data(id):
            server = r[0].copy()
            k = r[1]
        _ = server.put_int(server.root(), "SpawnX", Int32(pos.x()))
        _ = server.put_int(server.root(), "SpawnY", Int32(pos.y()))
        _ = server.put_int(server.root(), "SpawnZ", Int32(pos.z()))
        self._ldb.put(k.as_bytes(), Span(encode(server, LITTLE_ENDIAN)))

    # ===------------------------------------------------------------------=== #
    # Columns
    # ===------------------------------------------------------------------=== #

    def load_column(
        mut self, pos: ChunkPos, dim: Dimension
    ) raises -> Optional[Column]:
        """Loads a column (Go `LoadColumn`)."""
        return self.read_column(pos, dim)

    def read_column(
        self, pos: ChunkPos, dim: Dimension
    ) raises -> Optional[Column]:
        """Loads a column without needing mutable access (`load_column`)."""
        try:
            return self._column(pos, dim)
        except e:
            raise Error(t"load column {pos} ({dim}): {e}")

    def _version(self, pos: ChunkPos, dim: Dimension) raises -> Optional[UInt8]:
        var p = self._ldb.get(Span(_key(pos, dim, KEY_VERSION)))
        if not p:
            p = self._ldb.get(Span(_key(pos, dim, KEY_VERSION_OLD)))
            if not p:
                return None
        if len(p.value()) != 1:
            raise Error(
                t"read version: expected 1 version byte, got {len(p.value())}"
            )
        return p.value()[0]

    def _column(self, pos: ChunkPos, dim: Dimension) raises -> Optional[Column]:
        if not self._version(pos, dim):
            return None
        var r = dim.range()
        var cdata = SerialisedData()
        if case .Some(b) = self._ldb.get(Span(_key(pos, dim, KEY_3D_DATA))):
            # The first 512 bytes are a height map, recalculated on load.
            if len(b) <= 512:
                raise Error(
                    t"read biomes: expected at least 513 bytes for 3D data, got"
                    t" {len(b)}"
                )
            cdata.biomes = List[UInt8](Span(b)[512:])
        var n = (r.height() >> 4) + 1
        for i in range(n):
            var k = _key(pos, dim, KEY_SUB_CHUNK_DATA)
            k.append(UInt8((i + (r.min() >> 4)) & 0xFF))
            cdata.sub_chunks.append(
                self._ldb.get(Span(k)).or_else(List[UInt8]())
            )
        var c = disk_decode(self._blocks[], self._upgrades, cdata, r)
        if self._ldb.has(Span(_key(pos, dim, KEY_LEGACY_STATES))):
            c.mark_legacy_states()
        var col = Column(c^)
        col.entities = self._entities(pos, dim)
        col.block_entities = self._block_entities(pos, dim)
        self._scheduled_updates(pos, dim, col)
        return col^

    def _entities(self, pos: ChunkPos, dim: Dimension) raises -> List[Entity]:
        # https://learn.microsoft.com/en-us/minecraft/creator/documents/actorstorage
        var idk = List[UInt8](KEY_ENTITY_IDENTIFIERS.as_bytes())
        idk.extend(Span(index(pos, dim)))
        var ids = self._ldb.get(Span(idk))
        if not ids:
            return self._entities_old(pos, dim)
        var out = List[Entity]()
        ref b = ids.value()
        var i = 0
        while i + 8 <= len(b):
            var id = Int64(_get_u64(Span(b), i))
            var data = self._ldb.get(Span(entity_index(id)))
            if not data:
                raise Error(t"read entity {id}: not found")
            try:
                out.append(
                    Entity(id, decode(Span(data.value()), LITTLE_ENDIAN))
                )
            except e:
                raise Error(t"decode entity nbt {id}: {e}")
            i += 8
        return out^

    def _entities_old(
        self, pos: ChunkPos, dim: Dimension
    ) raises -> List[Entity]:
        var out = List[Entity]()
        var data = self._ldb.get(Span(_key(pos, dim, KEY_ENTITIES_OLD)))
        if not data:
            return out^
        ref b = data.value()
        var p = 0
        while p < len(b):
            var t = decode_from(Span(b), p, LITTLE_ENDIAN)
            var id = Int64(0)
            var ok = False
            if case .Some(e) = t.get(t.root(), "UniqueID"):
                if t.type_of(e) == TAG_LONG:
                    id = t.as_long(e)
                    ok = True
            if not ok:
                # Go draws a random ID here; a missing ID becomes 0.
                id = 0
            out.append(Entity(id, t^))
        return out^

    def _block_entities(
        self, pos: ChunkPos, dim: Dimension
    ) raises -> List[BlockEntity]:
        var out = List[BlockEntity]()
        var data = self._ldb.get(Span(_key(pos, dim, KEY_BLOCK_ENTITIES)))
        if not data:
            return out^
        ref b = data.value()
        var p = 0
        while p < len(b):
            var t = decode_from(Span(b), p, LITTLE_ENDIAN)
            var bp = _block_pos_from_nbt(t, t.root())
            out.append(BlockEntity(bp, t^))
        return out^

    def _scheduled_updates(
        self, pos: ChunkPos, dim: Dimension, mut col: Column
    ) raises:
        var data = self._ldb.get(
            Span(_key(pos, dim, KEY_PENDING_SCHEDULED_TICKS))
        )
        if not data:
            return
        var t = decode(Span(data.value()), LITTLE_ENDIAN)
        var root = t.root()
        if case .Some(e) = t.get(root, "currentTick"):
            col.tick = Int64(t.as_int(e))
        if case .Some(list) = t.get(root, "tickList"):
            for tick in t.children(list):
                var tm = Int64(0)
                if case .Some(e) = t.get(tick, "time"):
                    if t.type_of(e) == TAG_LONG:
                        tm = t.as_long(e)
                var bs = t.get(tick, "blockState")
                if not bs or t.type_of(bs.value()) != TAG_COMPOUND:
                    continue
                var legacy = False
                try:
                    var rid = decode_disk_block_state(
                        self._blocks[], self._upgrades, t, bs.value(), legacy
                    )
                    col.scheduled_blocks.append(
                        ScheduledBlockUpdate(
                            _block_pos_from_nbt(t, tick), rid, tm
                        )
                    )
                except:
                    continue

    def store_column(
        mut self, pos: ChunkPos, dim: Dimension, var col: Column
    ) raises:
        """Stores a column in one atomic batch (Go `StoreColumn`)."""
        try:
            self._store_column(pos, dim, col)
        except e:
            raise Error(t"store column {pos} ({dim}): {e}")

    def _store_column(
        mut self, pos: ChunkPos, dim: Dimension, mut col: Column
    ) raises:
        var data = disk_encode(col.chunk, self._blocks[])
        var batch = Batch()
        batch.put(Span(_key(pos, dim, KEY_VERSION)), [CHUNK_VERSION])
        var biomes = List[UInt8](length=512, fill=0)
        biomes.extend(Span(data.biomes))
        batch.put(Span(_key(pos, dim, KEY_3D_DATA)), Span(biomes))
        var r = col.chunk.range()
        for i in range(len(data.sub_chunks)):
            var k = _key(pos, dim, KEY_SUB_CHUNK_DATA)
            k.append(UInt8((i + (r.min() >> 4)) & 0xFF))
            batch.put(Span(k), Span(data.sub_chunks[i]))
        var fin = List[UInt8]()
        _put_u32(fin, FINALISATION_POPULATED)
        batch.put(Span(_key(pos, dim, KEY_FINALISATION)), Span(fin))
        # Go storeLegacyStates.
        var lk = _key(pos, dim, KEY_LEGACY_STATES)
        if col.chunk.legacy_states():
            batch.put(Span(lk), [UInt8(1)])
        else:
            batch.delete(Span(lk))
        self._store_entities(batch, pos, dim, col.entities)
        self._store_block_entities(batch, pos, dim, col.block_entities)
        self._store_scheduled_updates(
            batch, pos, dim, col.tick, col.scheduled_blocks
        )
        self._ldb.write(batch)

    def _store_entities(
        self,
        mut batch: Batch,
        pos: ChunkPos,
        dim: Dimension,
        mut entities: List[Entity],
    ) raises:
        var idk = List[UInt8](KEY_ENTITY_IDENTIFIERS.as_bytes())
        idk.extend(Span(index(pos, dim)))
        var previous = List[Int64]()
        if case .Some(b) = self._ldb.get(Span(idk)):
            var i = 0
            while i + 8 <= len(b):
                previous.append(Int64(_get_u64(Span(b), i)))
                i += 8
        var new_ids = List[Int64]()
        for ref e in entities:
            _ = e.data.put_long(e.data.root(), "UniqueID", e.id)
            batch.put(
                Span(entity_index(e.id)), Span(encode(e.data, LITTLE_ENDIAN))
            )
            new_ids.append(e.id)
        for id in previous:
            if id not in new_ids:
                batch.delete(Span(entity_index(id)))
        if len(entities) == 0:
            batch.delete(Span(idk))
        else:
            var ids = List[UInt8](capacity=8 * len(new_ids))
            for id in new_ids:
                _put_u64(ids, UInt64(id))
            batch.put(Span(idk), Span(ids))
        batch.delete(Span(_key(pos, dim, KEY_ENTITIES_OLD)))

    def _store_block_entities(
        self,
        mut batch: Batch,
        pos: ChunkPos,
        dim: Dimension,
        mut bes: List[BlockEntity],
    ) raises:
        var k = _key(pos, dim, KEY_BLOCK_ENTITIES)
        if len(bes) == 0:
            batch.delete(Span(k))
            return
        var buf = List[UInt8]()
        for ref b in bes:
            var root = b.data.root()
            _ = b.data.put_int(root, "x", Int32(b.pos.x()))
            _ = b.data.put_int(root, "y", Int32(b.pos.y()))
            _ = b.data.put_int(root, "z", Int32(b.pos.z()))
            encode_to(b.data, LITTLE_ENDIAN, buf)
        batch.put(Span(k), Span(buf))

    def _store_scheduled_updates(
        self,
        mut batch: Batch,
        pos: ChunkPos,
        dim: Dimension,
        tick: Int64,
        updates: List[ScheduledBlockUpdate],
    ) raises:
        var k = _key(pos, dim, KEY_PENDING_SCHEDULED_TICKS)
        if len(updates) == 0:
            batch.delete(Span(k))
            return
        var t = Tree()
        var root = t.root()
        _ = t.put_int(root, "currentTick", Int32(tick))
        var list = t.put_list(root, "tickList", TAG_COMPOUND)
        for ref u in updates:
            var c = t.append_compound(list)
            _ = t.put_int(c, "x", Int32(u.pos.x()))
            _ = t.put_int(c, "y", Int32(u.pos.y()))
            _ = t.put_int(c, "z", Int32(u.pos.z()))
            _ = t.put_long(c, "time", u.tick)
            encode_disk_block_state(
                self._blocks[], u.block, t, t.put_compound(c, "blockState")
            )
        batch.put(Span(k), Span(encode(t, LITTLE_ENDIAN)))

    def close(mut self) raises:
        """Writes `level.dat` and `levelname.txt` and syncs the database
        (Go `Close`). The provider stays usable; dropping it closes the
        files."""
        self._ldat.last_played = Int64(unix_time_s())
        var l = LevelDat()
        l.marshal(self._ldat)
        l.write_file(join(self._dir, "level.dat"))
        write_file(
            join(self._dir, "levelname.txt"),
            self._ldat.level_name.as_bytes(),
            sync=True,
        )
        self._ldb.sync()
