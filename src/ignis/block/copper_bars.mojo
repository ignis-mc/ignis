"""`CopperBars`, ported from Dragonfly `server/block/copper_bars.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): NeighbourUpdateTick, DeriveState, SideClosed, Wax, Strip,
RandomTick (attemptOxidation) and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .connections import Connections, all_connections
from .hash import HASH_COPPER_BARS
from .model.thin import Thin as ThinModel
from .oxidation_type import OxidationType, oxidation_types
from .oxidizable import Oxidisable, copper_block_name


struct CopperBars(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    Oxidisable,
):
    """A pane-like block made of copper."""

    comptime BASE_HASH: UInt64 = HASH_COPPER_BARS
    """Go `hashCopperBars`."""
    comptime ModelType = ThinModel
    """The model type (Go `Model`)."""

    var oxidation: OxidationType
    """The level of oxidation of the block."""
    var waxed: Bool
    """Whether the block is waxed, which stops it from oxidising."""
    var connections: Connections
    """The sides the bars connect on."""

    def __init__(
        out self,
        *,
        oxidation: OxidationType = OxidationType.UNOXIDISED,
        waxed: Bool = False,
        connections: Connections = Connections(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            oxidation: The level of oxidation of the block.
            waxed: Whether the block is waxed, which stops it from oxidising.
            connections: The sides the bars connect on.
        """
        self.oxidation = oxidation
        self.waxed = waxed
        self.connections = connections

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
            copper_block_name("copper_bars", self.oxidation, self.waxed),
            self.connections.properties(Properties()),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.oxidation.uint8())
            | (UInt64(1) if self.waxed else UInt64(0)) << 2
            | UInt64(self.connections.uint8()) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return CopperBars(
            oxidation=OxidationType(Int(hash & 0x3)),
            waxed=(hash >> 2) & 0x1 != 0,
            connections=Connections(bits=Int((hash >> 3) & 0xF)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for waxed in [True, False]:
            for o in oxidation_types():
                for c in all_connections():
                    out.append(
                        CopperBars(oxidation=o, waxed=waxed, connections=c)
                    )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def can_oxidate(self) -> Bool:
        """Reports whether the block can still oxidise (Go `CanOxidate`).

        Returns:
            True unless the block is waxed.
        """
        return not self.waxed

    def oxidation_level(self) -> OxidationType:
        """Returns the oxidation level (Go `OxidationLevel`).

        Returns:
            The oxidation level.
        """
        return self.oxidation

    def with_oxidation_level(self, o: OxidationType) -> Self:
        """Returns the block with another oxidation level (Go
        `WithOxidationLevel`).

        Args:
            o: The new oxidation level.

        Returns:
            The updated block.
        """
        var b = self
        b.oxidation = o
        return b

    def model(self) -> ThinModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return ThinModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            copper_block_name("copper_bars", self.oxidation, self.waxed), 0
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for o in oxidation_types():
            out.append(Self(oxidation=o))
            out.append(Self(oxidation=o, waxed=True))
        return out^
