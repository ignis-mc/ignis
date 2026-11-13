"""The block registry, ported from Dragonfly `server/world/block_registry.go`
and the loading part of `server/world/block_state.go`.

Runtime IDs are assigned exactly as Dragonfly assigns them: every state in
`block_states.nbt` is registered in file order, then `finalize` sorts them
stably by the FNV-1 64 hash of the block name. Dragonfly's `StartGame` does
not set `UseBlockNetworkIDHashes`, so these sequential runtime IDs are what
goes on the wire; the network block hashes are kept for lookups in both
directions.

Differences from Go:

- There is no global `DefaultBlockRegistry`; the server builds one with
  `ignis.block.register.vanilla_block_registry` and owns it.
- A block of unknown type is its runtime ID, so `BlockByRuntimeID` and
  friends return runtime IDs or typed values (`block[T]`), not interfaces.
- Misuse that panics in Go (registering after `finalize`, duplicate states)
  raises; looking up the runtime ID of an unregistered block aborts, like
  Go's panic, because it is a programming error on a hot path.
- `state_key` replaces `hashProperties`; see `block_state.mojo`.
"""

from std.collections import Dict
from std.os import abort

from minecraft.nbt.decode import decode_from
from minecraft.nbt.nbt import NETWORK_LITTLE_ENDIAN

from ..internal.fnv import fnv1_64
from .block import Block, LightDiffuser, LightEmitter
from .block_state import (
    BlockState,
    Properties,
    decode_block_state,
    state_key,
)
from .chunk.block_registry import BlockRegistry
from .network_block_hash import network_block_hash

comptime UNKNOWN_KIND: UInt64 = UInt64.MAX
"""The kind of runtime IDs whose state has no registered block type (Go
`unknownBlock`)."""

comptime _FLAG_NBT: UInt16 = 1 << 0
comptime _FLAG_RANDOM_TICK: UInt16 = 1 << 1
comptime _FLAG_LIQUID: UInt16 = 1 << 2
comptime _FLAG_LIQUID_DISPLACING: UInt16 = 1 << 3


@fieldwise_init
struct BlockInfo(Equatable, ImplicitlyCopyable):
    """Packed per-runtime-ID properties used in hot paths (Go `blockInfo`).

    Bits 0 to 3 are flags, bits 8 to 11 the light emission level and bits 12
    to 15 the light filtering level.
    """

    var bits: UInt16
    """The packed value."""

    def set(mut self, flag: UInt16):
        """Sets a flag.

        Args:
            flag: The flag bit.
        """
        self.bits |= flag

    def get(self, flag: UInt16) -> Bool:
        """Reports whether a flag is set.

        Args:
            flag: The flag bit.

        Returns:
            True if the flag is set.
        """
        return self.bits & flag != 0

    def set_light(mut self, light: UInt8):
        """Sets the light emission level.

        Args:
            light: The level; only the low 4 bits are kept.
        """
        self.bits = (self.bits & ~(UInt16(0xF) << 8)) | (
            UInt16(light & 0xF) << 8
        )

    def set_light_filter(mut self, light: UInt8):
        """Sets the light filtering level.

        Args:
            light: The level; only the low 4 bits are kept.
        """
        self.bits = (self.bits & ~(UInt16(0xF) << 12)) | (
            UInt16(light & 0xF) << 12
        )

    def get_light(self) -> UInt8:
        """Returns the light emission level.

        Returns:
            The level.
        """
        return UInt8((self.bits >> 8) & 0xF)

    def get_light_filter(self) -> UInt8:
        """Returns the light filtering level.

        Returns:
            The level.
        """
        return UInt8((self.bits >> 12) & 0xF)


def _bit_len(n: Int) -> Int:
    var bits = 0
    var v = UInt64(n)
    while v != 0:
        bits += 1
        v >>= 1
    return bits


def _stable_sort_by(mut order: List[Int], keys: List[UInt64]):
    """Merge-sorts indices by key, keeping equal keys in their order."""
    var n = len(order)
    var tmp = List[Int](length=n, fill=0)
    var width = 1
    while width < n:
        var lo = 0
        while lo < n:
            var mid = min(lo + width, n)
            var hi = min(lo + 2 * width, n)
            var i = lo
            var j = mid
            var k = lo
            while i < mid and j < hi:
                if keys[order[j]] < keys[order[i]]:
                    tmp[k] = order[j]
                    j += 1
                else:
                    tmp[k] = order[i]
                    i += 1
                k += 1
            while i < mid:
                tmp[k] = order[i]
                i += 1
                k += 1
            while j < hi:
                tmp[k] = order[j]
                j += 1
                k += 1
            lo += 2 * width
        for x in range(n):
            order[x] = tmp[x]
        width *= 2


struct BasicBlockRegistry(BlockRegistry, Copyable, Defaultable):
    """Converts between runtime IDs, block states and block types (Go
    `BasicBlockRegistry`).

    The registry is built in two phases: states and blocks are registered,
    then `finalize` assigns the final runtime IDs and builds the lookup
    tables. Lookups are only valid after `finalize`.
    """

    var _finalized: Bool
    var _bit_size: Int
    var _hashes: Dict[UInt64, UInt32]
    var _networkhash_to_rids: Dict[UInt32, UInt32]
    var _rids_to_networkhash: List[UInt32]
    var _state_runtime_ids: Dict[String, UInt32]
    var _block_properties: Dict[String, Properties]
    var _states: List[BlockState]
    var _kinds: List[UInt64]
    var _state_hashes: List[UInt64]
    var _block_infos: List[BlockInfo]
    var _air_rid: UInt32

    def __init__(out self):
        """Creates an empty, unfinalized registry."""
        self._finalized = False
        self._bit_size = 0
        self._hashes = Dict[UInt64, UInt32]()
        self._networkhash_to_rids = Dict[UInt32, UInt32]()
        self._rids_to_networkhash = List[UInt32]()
        self._state_runtime_ids = Dict[String, UInt32]()
        self._block_properties = Dict[String, Properties]()
        self._states = List[BlockState]()
        self._kinds = List[UInt64]()
        self._state_hashes = List[UInt64]()
        self._block_infos = List[BlockInfo]()
        self._air_rid = 0

    @staticmethod
    def from_block_states(data: Span[UInt8, _]) raises -> Self:
        """Creates a registry holding every state in a `block_states.nbt`
        file (Go `block_state.go` `init`).

        Args:
            data: The file: concatenated network little-endian compounds.

        Returns:
            An unfinalized registry.

        Raises:
            If the data is malformed or holds a state twice.
        """
        var br = Self()
        var pos = 0
        while pos < len(data):
            var tree = decode_from(data, pos, NETWORK_LITTLE_ENDIAN)
            br.register_block_state(decode_block_state(tree))
        return br^

    @staticmethod
    def load(path: String) raises -> Self:
        """Creates a registry from a `block_states.nbt` file on disk.

        Args:
            path: The path of the file.

        Returns:
            An unfinalized registry.

        Raises:
            If the file cannot be read or is malformed.
        """
        var data: List[UInt8]
        with open(path, "r") as f:
            data = f.read_bytes()
        return Self.from_block_states(Span(data))

    def register_block_state(mut self, var s: BlockState) raises:
        """Registers a state that blocks may encode to.

        Args:
            s: The state.

        Raises:
            If the registry is finalized or the state is already registered.
        """
        if self._finalized:
            raise Error("register_block_state called on finalized registry")
        var key = state_key(s.name, s.properties)
        if key in self._state_runtime_ids:
            raise Error(t"cannot register the same state twice ({s})")
        if s.name not in self._block_properties:
            self._block_properties[s.name] = s.properties.copy()
        var rid = UInt32(len(self._states))
        self._states.append(s^)
        self._kinds.append(UNKNOWN_KIND)
        self._state_hashes.append(UInt64.MAX)
        var info = BlockInfo(0)
        info.set_light_filter(15)
        self._block_infos.append(info)
        self._state_runtime_ids[key^] = rid

    def register_block[T: Block](mut self, b: T) raises:
        """Registers a block implementation for a previously registered state.

        The light levels and flags of the state come from the traits `T`
        conforms to, as Go derives them from the interfaces a block
        implements.

        Parameters:
            T: The block type.

        Args:
            b: The block.

        Raises:
            If the registry is finalized, the state is not registered or
            already has an implementation.
        """
        if self._finalized:
            raise Error("register_block called on finalized registry")
        var s = b.encode_block()
        var key = state_key(s.name, s.properties)
        var found = self._state_runtime_ids.get(key)
        if not found:
            raise Error(t"block state returned is not registered ({s})")
        var rid = Int(found.value())
        if self._kinds[rid] != UNKNOWN_KIND:
            raise Error(t"block {s} already registered")
        self._kinds[rid] = T.BASE_HASH
        self._state_hashes[rid] = b.hash()
        # Keep the implementation's encoding, as Go keeps the block itself.
        self._states[rid].properties = s.properties.copy()
        var info = BlockInfo(0)
        info.set_light_filter(15)
        comptime if conforms_to(T, LightDiffuser):
            info.set_light_filter(_diffusion[T](b))
        comptime if conforms_to(T, LightEmitter):
            info.set_light(_emission[T](b))
        # TODO: NBTer, RandomTicker, Liquid and LiquidDisplacer flags once
        # those traits are ported with world.Tx.
        self._block_infos[rid] = info

    def finalize(mut self) raises:
        """Assigns the final runtime IDs and builds the lookup tables (Go
        `Finalize`). Calling it again does nothing.

        Raises:
            If two states or blocks collide, or no air state is registered.
        """
        if self._finalized:
            return
        var n = len(self._states)
        self._bit_size = _bit_len(n)

        var keys = List[UInt64](capacity=n)
        var order = List[Int](capacity=n)
        for i in range(n):
            keys.append(fnv1_64(self._states[i].name.as_bytes()))
            order.append(i)
        _stable_sort_by(order, keys)

        var states = List[BlockState](capacity=n)
        var kinds = List[UInt64](capacity=n)
        var state_hashes = List[UInt64](capacity=n)
        var infos = List[BlockInfo](capacity=n)
        for i in order:
            states.append(self._states[i].copy())
            kinds.append(self._kinds[i])
            state_hashes.append(self._state_hashes[i])
            infos.append(self._block_infos[i])

        var hashes = Dict[UInt64, UInt32]()
        var net_to_rid = Dict[UInt32, UInt32]()
        var rid_to_net = List[UInt32](capacity=n)
        var state_rids = Dict[String, UInt32]()
        var scratch = List[UInt8](capacity=255)
        var found_air = False
        for idx in range(n):
            var rid = UInt32(idx)
            ref s = states[idx]
            if s.name == "minecraft:air":
                self._air_rid = rid
                found_air = True
            var key = state_key(s.name, s.properties)
            if key in state_rids:
                raise Error(t"cannot register the same state twice ({s})")
            state_rids[key^] = rid
            if kinds[idx] != UNKNOWN_KIND:
                var h = kinds[idx] | (
                    state_hashes[idx] << UInt64(self._bit_size)
                )
                if h in hashes:
                    raise Error(t"block {s} with hash {h} already registered")
                hashes[h] = rid
            var net = network_block_hash(s.name, s.properties, scratch)
            if net in net_to_rid:
                raise Error(t"network block hash collision for {s}")
            net_to_rid[net] = rid
            rid_to_net.append(net)
        if not found_air:
            raise Error("finalize: no minecraft:air block state registered")

        self._states = states^
        self._kinds = kinds^
        self._state_hashes = state_hashes^
        self._block_infos = infos^
        self._hashes = hashes^
        self._networkhash_to_rids = net_to_rid^
        self._rids_to_networkhash = rid_to_net^
        self._state_runtime_ids = state_rids^
        self._finalized = True

    def finalized(self) -> Bool:
        """Reports whether `finalize` has run.

        Returns:
            True after `finalize`.
        """
        return self._finalized

    def bit_size(self) -> Int:
        """Returns the number of bits used by the type part of `block_hash`.

        Returns:
            The bit length of the number of runtime IDs.
        """
        debug_assert(self._finalized, "bit_size on non-finalized registry")
        return self._bit_size

    def block_count(self) -> Int:
        """Returns the number of runtime IDs.

        Returns:
            The number of registered states.
        """
        debug_assert(self._finalized, "block_count on non-finalized registry")
        return len(self._block_infos)

    def air_runtime_id(self) -> UInt32:
        """Returns the runtime ID of air.

        Returns:
            The air runtime ID.
        """
        debug_assert(
            self._finalized, "air_runtime_id on non-finalized registry"
        )
        return self._air_rid

    def air(self) -> UInt32:
        """Returns the air block (Go `Air`), which is its runtime ID here.

        Returns:
            The air runtime ID.
        """
        return self.air_runtime_id()

    def runtime_id_to_state(self, runtime_id: UInt32) -> Optional[BlockState]:
        """Returns the name and properties of a runtime ID.

        Args:
            runtime_id: The runtime ID.

        Returns:
            The state, or None if the runtime ID is out of range.
        """
        debug_assert(self._finalized, "runtime_id_to_state on non-finalized")
        if Int(runtime_id) >= len(self._states):
            return None
        return self._states[Int(runtime_id)].copy()

    def state(ref self, runtime_id: UInt32) -> ref[self._states[0]] BlockState:
        """Returns the state of a runtime ID known to be valid, without
        copying it.

        Args:
            runtime_id: A runtime ID below `block_count()`.

        Returns:
            A reference to the state.
        """
        return self._states[Int(runtime_id)]

    def state_to_runtime_id(
        self, name: StringSlice, properties: Properties
    ) -> Optional[UInt32]:
        """Returns the runtime ID of a name and properties, or of the block's
        default state if the properties match none.

        Args:
            name: The block name.
            properties: The properties.

        Returns:
            The runtime ID, or None if the name is unknown.
        """
        debug_assert(self._finalized, "state_to_runtime_id on non-finalized")
        if case .Some(rid) = self._state_runtime_ids.get(
            state_key(name, properties)
        ):
            return rid
        if case .Some(defaults) = self._block_properties.get(String(name)):
            return self._state_runtime_ids.get(state_key(name, defaults))
        return None

    def default_properties(self, name: StringSlice) -> Optional[Properties]:
        """Returns the properties of the first state registered for a name,
        which is the block's default state.

        Args:
            name: The block name.

        Returns:
            The properties, or None if the name is unknown.
        """
        debug_assert(self._finalized, "default_properties on non-finalized")
        return self._block_properties.get(String(name))

    def block_by_name(
        self, name: StringSlice, properties: Properties
    ) -> Optional[UInt32]:
        """Looks up a block by its exact name and properties (Go
        `BlockByName`).

        Args:
            name: The block name.
            properties: The properties.

        Returns:
            The runtime ID, or None if no such state is registered.
        """
        debug_assert(self._finalized, "block_by_name on non-finalized")
        return self._state_runtime_ids.get(state_key(name, properties))

    def filtering_block(self, rid: UInt32) -> UInt8:
        """Returns how much light the block filters.

        Args:
            rid: The runtime ID.

        Returns:
            The light filtering level, 15 for opaque blocks.
        """
        return self._block_infos[Int(rid)].get_light_filter()

    def light_block(self, rid: UInt32) -> UInt8:
        """Returns the light level the block emits.

        Args:
            rid: The runtime ID.

        Returns:
            The light emission level.
        """
        return self._block_infos[Int(rid)].get_light()

    def random_tick_block(self, rid: UInt32) -> Bool:
        """Reports whether the block receives random ticks.

        Args:
            rid: The runtime ID.

        Returns:
            True for random-ticking blocks.
        """
        return self._block_infos[Int(rid)].get(_FLAG_RANDOM_TICK)

    def nbt_block(self, rid: UInt32) -> Bool:
        """Reports whether the block carries NBT data.

        Args:
            rid: The runtime ID.

        Returns:
            True for blocks with NBT data.
        """
        return self._block_infos[Int(rid)].get(_FLAG_NBT)

    def liquid_displacing_block(self, rid: UInt32) -> Bool:
        """Reports whether the block displaces liquids.

        Args:
            rid: The runtime ID.

        Returns:
            True for liquid displacers.
        """
        return self._block_infos[Int(rid)].get(_FLAG_LIQUID_DISPLACING)

    def liquid_block(self, rid: UInt32) -> Bool:
        """Reports whether the block is a liquid.

        Args:
            rid: The runtime ID.

        Returns:
            True for liquids.
        """
        return self._block_infos[Int(rid)].get(_FLAG_LIQUID)

    def hash_to_runtime_id(self, hash: UInt32) -> Optional[UInt32]:
        """Resolves a network block hash to a runtime ID.

        Args:
            hash: The network block hash.

        Returns:
            The runtime ID, or None if no state has the hash.
        """
        debug_assert(self._finalized, "hash_to_runtime_id on non-finalized")
        return self._networkhash_to_rids.get(hash)

    def runtime_id_to_hash(self, runtime_id: UInt32) -> Optional[UInt32]:
        """Resolves a runtime ID to its network block hash.

        Args:
            runtime_id: The runtime ID.

        Returns:
            The hash, or None if the runtime ID is out of range.
        """
        debug_assert(self._finalized, "runtime_id_to_hash on non-finalized")
        if Int(runtime_id) >= len(self._rids_to_networkhash):
            return None
        return self._rids_to_networkhash[Int(runtime_id)]

    def kind(self, rid: UInt32) -> UInt64:
        """Returns the `BASE_HASH` of the type registered for a runtime ID.

        Args:
            rid: A runtime ID below `block_count()`.

        Returns:
            The base hash, or `UNKNOWN_KIND` for states without a type.
        """
        return self._kinds[Int(rid)]

    def state_hash(self, rid: UInt32) -> UInt64:
        """Returns the state hash of the block registered for a runtime ID.

        Args:
            rid: A runtime ID below `block_count()`.

        Returns:
            The value `hash()` returned for the block, or `UInt64.MAX` for
            states without a type.
        """
        return self._state_hashes[Int(rid)]

    def block_hash[T: Block](self, b: T) -> UInt64:
        """Returns a registry-unique identifier of the block including its
        state (Go `BlockHash`); it does not match anything in the game.

        Parameters:
            T: The block type.

        Args:
            b: The block.

        Returns:
            `T.BASE_HASH | b.hash() << bit_size()`.
        """
        return T.BASE_HASH | (b.hash() << UInt64(self._bit_size))

    def block_runtime_id[T: Block](self, b: T) -> UInt32:
        """Returns the runtime ID of a registered block (Go
        `BlockRuntimeID`). Aborts if the block was never registered.

        Parameters:
            T: The block type.

        Args:
            b: The block.

        Returns:
            The runtime ID.
        """
        debug_assert(self._finalized, "block_runtime_id on non-finalized")
        if case .Some(rid) = self._hashes.get(self.block_hash(b)):
            return rid
        abort(t"cannot find block by hash: {b.encode_block()}")

    def runtime_id_of(self, kind: UInt64, hash: UInt64) -> Optional[UInt32]:
        """Returns the runtime ID of a block given its type's base hash and
        its state hash, for blocks whose type is only known at run time
        (for example a block held as an `AnyItem`).

        Args:
            kind: The type's `BASE_HASH`.
            hash: The block's `hash()`.

        Returns:
            The runtime ID, or None if no such block is registered.
        """
        return self._hashes.get(kind | (hash << UInt64(self._bit_size)))

    def is_block[T: Block](self, rid: UInt32) -> Bool:
        """Reports whether a runtime ID holds a block of type `T` (Go
        `b.(T)`).

        Parameters:
            T: The block type.

        Args:
            rid: The runtime ID.

        Returns:
            True if the state is registered by `T`.
        """
        return (
            Int(rid) < len(self._kinds) and self._kinds[Int(rid)] == T.BASE_HASH
        )

    def block[T: Block](self, rid: UInt32) -> Optional[T]:
        """Returns the block at a runtime ID as a `T` (Go `b, ok := x.(T)`).

        Parameters:
            T: The block type.

        Args:
            rid: The runtime ID.

        Returns:
            The block, or None if the runtime ID holds another type.
        """
        if not self.is_block[T](rid):
            return None
        return T.from_hash(self._state_hashes[Int(rid)])


def _diffusion[T: LightDiffuser](b: T) -> UInt8:
    return b.light_diffusion_level()


def _emission[T: LightEmitter](b: T) -> UInt8:
    return b.light_emission_level()
