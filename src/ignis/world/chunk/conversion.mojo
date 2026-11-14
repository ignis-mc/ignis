"""Upgrading stored block states, ported from Dragonfly
`server/world/chunk/conversion.go` plus the `df-mc/worldupgrader` schemas it
relies on.

Go keeps the legacy mappings and the upgrade schemas in package globals
filled at init. Ignis has no globals, so `Upgrades` owns both and is passed
to the disk decoder; load it once at startup.
"""

from std.collections import Dict

from minecraft.nbt.decode import decode_from
from minecraft.nbt.nbt import NETWORK_LITTLE_ENDIAN

from ...internal.fs import read_file
from ...worldupgrader.blockupgrader import BlockUpgrader, SCHEMA_DIR
from ..block_state import BlockState, Properties, PropertyValue
from minecraft.nbt.nbt import TAG_BYTE, TAG_COMPOUND, TAG_INT, TAG_STRING

comptime LEGACY_STATES_PATH = "resources/legacy_states.nbt"
"""Where Dragonfly's `legacy_states.nbt` is, relative to the working
directory."""


def _legacy_key(name: StringSlice, meta: Int16) -> String:
    return String(name, "\x00", meta)


struct Upgrades(Movable):
    """The legacy (pre-1.13) block mappings and the block state upgrade
    schemas."""

    var _legacy: Dict[String, BlockState]
    var blocks: BlockUpgrader
    """The block state upgrader (`blockupgrader`)."""

    def __init__(
        out self,
        var legacy: Dict[String, BlockState],
        var blocks: BlockUpgrader,
    ):
        """Creates the upgrades from loaded parts."""
        self._legacy = legacy^
        self.blocks = blocks^

    @staticmethod
    def load(
        legacy_path: StringSlice = LEGACY_STATES_PATH,
        schema_dir: StringSlice = SCHEMA_DIR,
    ) raises -> Self:
        """Loads `legacy_states.nbt` (Go `init` of `conversion.go`) and the
        upgrade schemas."""
        var data = read_file(legacy_path)
        var legacy = Dict[String, BlockState]()
        var pos = 0
        while pos < len(data):
            var t = decode_from(Span(data), pos, NETWORK_LITTLE_ENDIAN)
            var root = t.root()
            var old = t.get_compound(root, "legacy")
            var upd = t.get_compound(root, "updated")
            var meta = Int16(0)
            if t.has(old, "meta"):
                meta = t.get_short(old, "meta")
            var props = Properties()
            if case .Some(states) = t.get(upd, "states"):
                for c in t.children(states):
                    var ty = t.type_of(c)
                    if ty == TAG_BYTE:
                        props.set(t.name(c), PropertyValue(byte=t.as_byte(c)))
                    elif ty == TAG_INT:
                        props.set(t.name(c), PropertyValue(int32=t.as_int(c)))
                    elif ty == TAG_STRING:
                        props.set(
                            t.name(c), PropertyValue(string=t.as_string(c))
                        )
            var version = Int32(0)
            if t.has(upd, "version"):
                version = t.get_int(upd, "version")
            legacy[_legacy_key(t.get_string(old, "name"), meta)] = BlockState(
                t.get_string(upd, "name"), props^, version
            )
        return Self(legacy^, BlockUpgrader.load(schema_dir))

    def legacy_count(self) -> Int:
        """Returns the number of legacy mappings."""
        return len(self._legacy)

    def upgrade_legacy_entry(
        self, name: StringSlice, meta: Int16
    ) -> Optional[BlockState]:
        """Maps a pre-1.13 `name` and `meta` to a state (Go
        `upgradeLegacyEntry`), trying meta 0 when the exact meta is
        unknown."""
        if case .Some(s) = self._legacy.get(_legacy_key(name, meta)):
            return s.copy()
        return self._legacy.get(_legacy_key(name, 0))
