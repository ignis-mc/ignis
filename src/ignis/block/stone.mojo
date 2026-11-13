"""`Stone`, `Granite`, `Diorite`, `Andesite`, ported from Dragonfly
`server/block/stone.go`.

TODO(world-runtime): SmeltInfo and the `oneOf` drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_ANDESITE, HASH_DIORITE, HASH_GRANITE, HASH_STONE


struct Stone(Block, Breakable, Equatable, ImplicitlyCopyable, Item):
    """A block found underground in the world or on mountains."""

    comptime BASE_HASH: UInt64 = HASH_STONE
    """Go `hashStone`."""

    var smooth: Bool
    """Whether the stone is its smooth variant."""

    def __init__(out self, *, smooth: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            smooth: Whether the stone is its smooth variant.
        """
        self.smooth = smooth

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
        if self.smooth:
            return BlockState("minecraft:smooth_stone")
        return BlockState("minecraft:stone")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.smooth else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Stone(smooth=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Stone(smooth=True), Stone()]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`).

        Returns:
            `minecraft:smooth_stone` or `minecraft:stone`, metadata 0.
        """
        if self.smooth:
            return EncodedItem("minecraft:smooth_stone", 0)
        return EncodedItem("minecraft:stone", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`).

        Returns:
            Smooth stone and stone.
        """
        return [Stone(smooth=True), Stone()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        if self.smooth:
            return new_break_info(
                2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
            ).with_blast_resistance(6)
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)


struct Granite(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A type of igneous rock."""

    comptime BASE_HASH: UInt64 = HASH_GRANITE
    """Go `hashGranite`."""

    var polished: Bool
    """Whether the granite is polished."""

    def __init__(out self, *, polished: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            polished: Whether the granite is polished.
        """
        self.polished = polished

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
        if self.polished:
            return BlockState("minecraft:polished_granite")
        return BlockState("minecraft:granite")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.polished else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Granite(polished=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Granite(polished=True), Granite()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)


struct Diorite(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A type of igneous rock."""

    comptime BASE_HASH: UInt64 = HASH_DIORITE
    """Go `hashDiorite`."""

    var polished: Bool
    """Whether the diorite is polished."""

    def __init__(out self, *, polished: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            polished: Whether the diorite is polished.
        """
        self.polished = polished

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
        if self.polished:
            return BlockState("minecraft:polished_diorite")
        return BlockState("minecraft:diorite")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.polished else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Diorite(polished=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Diorite(polished=True), Diorite()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)


struct Andesite(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A type of igneous rock."""

    comptime BASE_HASH: UInt64 = HASH_ANDESITE
    """Go `hashAndesite`."""

    var polished: Bool
    """Whether the andesite is polished."""

    def __init__(out self, *, polished: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            polished: Whether the andesite is polished.
        """
        self.polished = polished

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
        if self.polished:
            return BlockState("minecraft:polished_andesite")
        return BlockState("minecraft:andesite")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.polished else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Andesite(polished=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Andesite(polished=True), Andesite()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)
