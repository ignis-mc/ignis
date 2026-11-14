"""`Beacon`, ported from Dragonfly `server/block/beacon.go`.

Go's `sourceWaterDisplacer` makes beacons a `LiquidDisplacer`; that trait
comes with liquids.

TODO(world-runtime): the `Primary` and `Secondary` `effect.LastingType` fields,
SideClosed, Activate, Level, Tick, recalculateLevel, obstructed,
broadcastBeaconEffects and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_int32
from ..world.block import Block, LightDiffuser, LightEmitter, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BEACON
from .model.solid import Solid as SolidModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct Beacon(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
):
    """A block that projects a light beam skyward, and can provide status effects such as Speed,
    Jump Boost, Haste, Regeneration, Resistance, or Strength to nearby players.
    """

    comptime BASE_HASH: UInt64 = HASH_BEACON
    """Go `hashBeacon`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var level: Int
    """The amount of pyramid levels the beacon is on, 0 to 4."""

    def __init__(out self, *, level: Int = 0):
        """Creates the block; omitted fields take Go zero values."""
        self.level = level

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash() and self.level == other.level

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:beacon")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Beacon()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Beacon()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(3, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 15

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:beacon", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "Beacon")
        _ = tag.put_int(root, "Levels", Int32(self.level))
        # TODO(world-runtime): Primary and Secondary, once the beacon holds
        # its effects.

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var b = self.copy()
        b.level = Int(get_int32(tag, root, "Levels"))
        return b^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
