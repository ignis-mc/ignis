"""The player data provider, ported from Dragonfly
`server/player/playerdb/leveldb.go`.

Each player's data is JSON (`playerdb.json.Data`) stored in a LevelDB
database with snappy compression, under the 16 bytes of the player's UUID.
"""

from minecraft.protocol.uuid import UUID

from ...internal.fs import make_dir_all
from ...leveldb.compress import SNAPPY_COMPRESSION
from ...leveldb.db import DB
from ...leveldb.options import Options
from .json import Data


struct Provider(Movable):
    """Player data in a LevelDB database (Go `playerdb.Provider`)."""

    var _db: DB

    def __init__(out self, path: StringSlice) raises:
        """Opens or creates the database in `path` (Go `NewProvider`)."""
        make_dir_all(path)
        var opts = Options()
        opts.compression = SNAPPY_COMPRESSION
        var db = DB(path, opts^)
        self._db = db^

    def save(mut self, id: UUID, d: Data) raises:
        """Stores a player's data (Go `Save`)."""
        var key = _key(id)
        self._db.put(Span(key), d.to_json().as_bytes())

    def load(self, id: UUID) raises -> Optional[Data]:
        """Loads a player's data, or None if there is none (Go `Load`, whose
        error makes the server use defaults)."""
        var key = _key(id)
        var b = self._db.get(Span(key))
        if not b:
            return None
        return Data.from_json(Span(b.value()))

    def close(mut self) raises:
        """Syncs the database to disk (Go `Close`); dropping the provider
        closes its files."""
        self._db.sync()


def _key(id: UUID) -> List[UInt8]:
    # Go `id[:]`.
    var k = List[UInt8](capacity=16)
    for i in range(16):
        k.append(id.bytes[i])
    return k^
