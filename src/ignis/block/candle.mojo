"""`Candle`, ported from Dragonfly `server/block/candle.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): UseOnBlock, Activate, Ignite, Splash, NeighbourUpdateTick,
SideClosed, HasLiquidDrops, Model and the drops.
"""

from ..item.optional_colour import OptionalColour, optional_colours
from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_CANDLE
from .model.candle import Candle as CandleModel


struct Candle(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
):
    """A dyeable block that emits light when lit with a flint and steel."""

    comptime BASE_HASH: UInt64 = HASH_CANDLE
    """Go `hashCandle`."""
    comptime ModelType = CandleModel
    """The model type (Go `Model`)."""

    var colour: OptionalColour
    """The colour of the candle, or none."""
    var additional_candles: Int
    """The number of additional candles in the block, 0 to 3."""
    var lit: Bool
    """Whether the candles are lit."""

    def __init__(
        out self,
        *,
        colour: OptionalColour = OptionalColour.NONE,
        additional_candles: Int = 0,
        lit: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            colour: The colour of the candle, or none.
            additional_candles: The number of additional candles in the block, 0 to 3.
            lit: Whether the candles are lit.
        """
        self.colour = colour
        self.additional_candles = additional_candles
        self.lit = lit

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
            "minecraft:" + self.colour.prepend("candle"),
            Properties()
            .with_int("candles", Int32(self.additional_candles))
            .with_bool("lit", self.lit),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.colour.uint8())
            | UInt64(self.additional_candles) << 5
            | (UInt64(1) if self.lit else UInt64(0)) << 13
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Candle(
            colour=OptionalColour(Int(hash & 0x1F)),
            additional_candles=Int((hash >> 5) & 0xFF),
            lit=(hash >> 13) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for i in range(4):
            for c in optional_colours():
                out.append(Candle(colour=c, additional_candles=i))
                out.append(Candle(colour=c, additional_candles=i, lit=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.1, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        if not self.lit:
            return 0
        return UInt8((self.additional_candles + 1) * 3)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> CandleModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return CandleModel(count=self.additional_candles + 1)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:" + self.colour.prepend("candle"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for c in optional_colours():
            out.append(Self(colour=c))
        return out^
