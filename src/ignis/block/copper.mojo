"""`Copper`, ported from Dragonfly `server/block/copper.go`.

TODO(world-runtime): Wax, Strip, RandomTick (attemptOxidation), EncodeItem
and the drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    HARVEST_LEVEL_STONE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
    pickaxe_harvestable_from,
)
from .copper_type import CopperType, copper_types
from .hash import HASH_COPPER
from .oxidation_type import OxidationType, oxidation_types
from .oxidizable import Oxidisable


struct Copper(Block, Breakable, Equatable, ImplicitlyCopyable, Oxidisable):
    """A solid block commonly found in deserts and beaches underneath sand."""

    comptime BASE_HASH: UInt64 = HASH_COPPER
    """Go `hashCopper`."""

    var type: CopperType
    """The type of copper of the block."""
    var oxidation: OxidationType
    """The level of oxidation of the block."""
    var waxed: Bool
    """Whether the block is waxed, which stops it from oxidising."""

    def __init__(
        out self,
        *,
        type: CopperType = CopperType.NORMAL,
        oxidation: OxidationType = OxidationType.UNOXIDISED,
        waxed: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The type of copper of the block.
            oxidation: The level of oxidation of the block.
            waxed: Whether the block is waxed, which stops it from oxidising.
        """
        self.type = type
        self.oxidation = oxidation
        self.waxed = waxed

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
        if (
            self.type == CopperType.NORMAL
            and self.oxidation == OxidationType.UNOXIDISED
            and not self.waxed
        ):
            return BlockState("minecraft:copper_block")
        var name = String("copper")
        if self.type != CopperType.NORMAL:
            name = String(t"{self.type}_{name}")
        if self.oxidation != OxidationType.UNOXIDISED:
            name = String(t"{self.oxidation}_{name}")
        if self.waxed:
            name = "waxed_" + name
        return BlockState("minecraft:" + name)

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.type.uint8())
            | UInt64(self.oxidation.uint8()) << 2
            | (UInt64(1) if self.waxed else UInt64(0)) << 4
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Copper(
            type=CopperType(Int(hash & 0x3)),
            oxidation=OxidationType(Int((hash >> 2) & 0x3)),
            waxed=(hash >> 4) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for waxed in [True, False]:
            for t in copper_types():
                for o in oxidation_types():
                    out.append(Copper(type=t, oxidation=o, waxed=waxed))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            3, pickaxe_harvestable_from(HARVEST_LEVEL_STONE), PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

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
