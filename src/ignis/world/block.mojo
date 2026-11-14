"""The `Block` trait, ported from Dragonfly `server/world/block.go`.

Go's `world.Block` is an interface with hundreds of implementations held as
interface values. Mojo 1.2 has traits but no trait objects, so Ignis splits
the two roles:

- Each block type is a struct conforming to `Block`. Code that knows the
  type works with it directly (`Dirt(coarse=True)`).
- A block of unknown type is its runtime ID (`UInt32`). The registry maps a
  runtime ID back to its type's `BASE_HASH` and state hash, from which
  `T.from_hash` rebuilds the value, and `BlockSet` dispatches behaviour to
  the type by `BASE_HASH`.

See `docs/architecture.md` for how block ports follow this.

Go passes `RandomTick` and `ScheduledTick` a `*rand.Rand` next to the
`*Tx`; the generator is part of the world here (`tx.rand()`), since passing
both would borrow the world twice.
"""

from minecraft.nbt.tree import Tag, Tree

from ..block.cube.pos import Pos
from ..block.hash import AnyBlock
from .block_state import BlockState
from .world import World, WorldTypes


trait Block(Copyable, Deinitable):
    """A block that may be placed or found in a world.

    Conforming types must make `from_hash(b.hash()) == b` hold for every
    value `b` they register.
    """

    comptime BASE_HASH: UInt64
    """The type's base hash (first value of Go's `Hash()`): the `hash*`
    constant generated for the type in `block/hash.go`, unique per type."""

    def encode_block(self) -> BlockState:
        """Encodes the block to its name and properties (Go `EncodeBlock`)."""
        ...

    def hash(self) -> UInt64:
        """Returns the hash of the block's own state (second value of Go's
        `Hash()`)."""
        ...

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from the value `hash` returned."""
        ...

    @staticmethod
    def all_states() -> List[Self]:
        """Returns every value of the type that is registered (the
        `RegisterBlock` calls for the type in Go's `block/register.go`)."""
        ...


trait NBTer(Copyable, Deinitable):
    """A block, item or entity with NBT data (Go `world.NBTer`).

    Go's map becomes a compound in a `Tree`; keys are written in the order
    Go's map literal lists them (Go's own order is random).
    """

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the value's NBT into the compound `root` (Go `EncodeNBT`)."""
        ...

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the value with the NBT of compound `root` decoded into it
        (Go `DecodeNBT`)."""
        ...


trait Container(NBTer):
    """A block holding items that viewers open (Go `block.Container`).

    The world keeps the inventory with the block entity, so the block only
    names its size; Go's `Inventory`, `AddViewer` and `RemoveViewer` are
    `World` methods.
    """

    def inventory_size(self) -> Int:
        """Returns the number of slots this block stores (a paired chest
        stores 27 of the 54 its window shows)."""
        ...


trait LightEmitter:
    """A block that emits light (Go `block.LightEmitter`; `world` uses the
    same trait for its private `lightEmitter`)."""

    def light_emission_level(self) -> UInt8:
        """Returns the light level the block emits, 0 to 15."""
        ...


trait LightDiffuser:
    """A block that lets light through partly or fully (Go
    `block.LightDiffuser`). Blocks that do not conform block all light."""

    def light_diffusion_level(self) -> UInt8:
        """Returns how much light the block takes away, 0 to 15."""
        ...


trait RandomTicker(Block):
    """A block that does something when it is ticked randomly (Go
    `RandomTicker`). Every tick, `RandomTickSpeed` random blocks of each
    sub-chunk near a viewer are picked."""

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Handles a random tick of the block."""
        ...


trait ScheduledTicker(Block):
    """A block that does something when an update scheduled for it is due
    (Go `ScheduledTicker`)."""

    def scheduled_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Handles a scheduled tick of the block."""
        ...


trait NeighbourUpdateTicker(Block):
    """A block that is updated when a block next to it changes (Go
    `NeighbourUpdateTicker`)."""

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Handles a neighbouring block being updated."""
        ...


trait Liquid(Block):
    """A block that can be moved through and flows after placement: water
    and lava (Go `world.Liquid`)."""

    def liquid_depth(self) -> Int:
        """Returns the depth of the liquid, 1 to 8 (Go `LiquidDepth`)."""
        ...

    def spread_decay(self) -> Int:
        """Returns the depth lost per block spread (Go `SpreadDecay`)."""
        ...

    def with_depth(self, depth: Int, falling: Bool) -> Self:
        """Returns the liquid with a depth and falling state (Go
        `WithDepth`)."""
        ...

    def liquid_falling(self) -> Bool:
        """Reports whether the liquid falls down (Go `LiquidFalling`)."""
        ...

    def blast_resistance(self) -> Float64:
        """Returns the blast resistance (Go `BlastResistance`)."""
        ...

    def liquid_type(self) -> StaticString:
        """Returns a name shared by liquids of the same type (Go
        `LiquidType`)."""
        ...

    def harden[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], flown_into_by: Optional[Pos]) -> Bool:
        """Hardens the liquid if the blocks around call for it; reports
        whether it did (Go `Harden`)."""
        ...

    def liquid_remove_block[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], removed: UInt32):
        """Called when the liquid flows into and removes a block (Go
        `LiquidRemoveBlock`)."""
        ...


trait LiquidDisplacer(Block):
    """A block that can hold a liquid on its second layer (Go
    `world.LiquidDisplacer`)."""

    def can_displace(self, b: AnyBlock) -> Bool:
        """Reports whether the block can hold the liquid `b` (Go
        `CanDisplace`)."""
        ...

    def side_closed[
        T: WorldTypes
    ](self, pos: Pos, side: Pos, mut tx: World[T]) -> Bool:
        """Reports whether liquid cannot flow from `pos` towards `side` (Go
        `SideClosed`); most blocks return False."""
        return False


@fieldwise_init
struct LiquidInfo(ImplicitlyCopyable):
    """The `Liquid` methods of a liquid of unknown type."""

    var liquid_type: StaticString
    """Go `LiquidType`."""
    var depth: Int
    """Go `LiquidDepth`."""
    var falling: Bool
    """Go `LiquidFalling`."""
    var spread_decay: Int
    """Go `SpreadDecay`."""

    def source(self) -> Bool:
        """Reports whether the liquid is a source block (Go `source`)."""
        return self.depth == 8 and not self.falling


def liquid_info[L: Liquid](l: L) -> LiquidInfo:
    """Returns the `LiquidInfo` of a typed liquid."""
    return LiquidInfo(
        l.liquid_type(), l.liquid_depth(), l.liquid_falling(), l.spread_decay()
    )
