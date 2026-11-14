"""`SeaPickle`, ported from Dragonfly `server/block/sea_pickle.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): canSurvive, BoneMeal, UseOnBlock, HasLiquidDrops,
NeighbourUpdateTick, SideClosed and the drops.
"""

from ..item.colour import Colour
from ..item.dye import Dye
from ..item.item import Compostable
from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .hash import HASH_SEA_PICKLE
from .model.empty import Empty as EmptyModel


struct SeaPickle(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
    Smeltable,
):
    """A small stationary underwater block that emits light."""

    comptime BASE_HASH: UInt64 = HASH_SEA_PICKLE
    """Go `hashSeaPickle`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var additional_count: Int
    """The number of additional sea pickles clustered together."""
    var dead: Bool
    """Whether the sea pickles are dead; they only live in water, where they emit light."""

    def __init__(out self, *, additional_count: Int = 0, dead: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            additional_count: The number of additional sea pickles clustered together.
            dead: Whether the sea pickles are dead; they only live in water, where they emit light.
        """
        self.additional_count = additional_count
        self.dead = dead

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state.
        """
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:sea_pickle",
            Properties()
            .with_int("cluster_count", Int32(self.additional_count))
            .with_bool("dead_bit", self.dead),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.additional_count)
            | (UInt64(1) if self.dead else UInt64(0)) << 8
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return SeaPickle(
            additional_count=Int(hash & 0xFF), dead=(hash >> 8) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for i in range(4):
            out.append(SeaPickle(additional_count=i))
            out.append(SeaPickle(additional_count=i, dead=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        if self.dead:
            return 0
        return UInt8(6 + self.additional_count * 3)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:sea_pickle", 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(Dye(colour=Colour.LIME), 1), 0.1)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
