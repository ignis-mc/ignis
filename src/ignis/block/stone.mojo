"""`Stone`, `Granite`, `Diorite`, `Andesite`, ported from Dragonfly
`server/block/stone.go`.

TODO(world-runtime): the `oneOf` drops.
"""

from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block
from ..world.block_model import ModelledBlock
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
from .model.solid import Solid as SolidModel


struct Stone(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A block found underground in the world or on mountains."""

    comptime BASE_HASH: UInt64 = HASH_STONE
    """Go `hashStone`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var smooth: Bool
    """Whether the stone is its smooth variant."""

    def __init__(out self, *, smooth: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.smooth = smooth

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.smooth:
            return BlockState("minecraft:smooth_stone")
        return BlockState("minecraft:stone")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.smooth else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Stone(smooth=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Stone(smooth=True), Stone()]

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`): stone smelts into smooth
        stone."""
        if self.smooth:
            return SmeltInfo()
        return SmeltInfo(Stack(Stone(smooth=True), 1), 0.1)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.smooth:
            return EncodedItem("minecraft:smooth_stone", 0)
        return EncodedItem("minecraft:stone", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`)."""
        return [Stone(smooth=True), Stone()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        if self.smooth:
            return new_break_info(
                2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
            ).with_blast_resistance(6)
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()


struct Granite(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A type of igneous rock."""

    comptime BASE_HASH: UInt64 = HASH_GRANITE
    """Go `hashGranite`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var polished: Bool
    """Whether the granite is polished."""

    def __init__(out self, *, polished: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.polished = polished

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.polished:
            return BlockState("minecraft:polished_granite")
        return BlockState("minecraft:granite")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.polished else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Granite(polished=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Granite(polished=True), Granite()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.polished:
            return EncodedItem("minecraft:polished_granite", 0)
        return EncodedItem("minecraft:granite", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self(polished=True), Self()]


struct Diorite(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A type of igneous rock."""

    comptime BASE_HASH: UInt64 = HASH_DIORITE
    """Go `hashDiorite`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var polished: Bool
    """Whether the diorite is polished."""

    def __init__(out self, *, polished: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.polished = polished

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.polished:
            return BlockState("minecraft:polished_diorite")
        return BlockState("minecraft:diorite")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.polished else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Diorite(polished=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Diorite(polished=True), Diorite()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.polished:
            return EncodedItem("minecraft:polished_diorite", 0)
        return EncodedItem("minecraft:diorite", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self(polished=True), Self()]


struct Andesite(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A type of igneous rock."""

    comptime BASE_HASH: UInt64 = HASH_ANDESITE
    """Go `hashAndesite`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var polished: Bool
    """Whether the andesite is polished."""

    def __init__(out self, *, polished: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.polished = polished

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.polished:
            return BlockState("minecraft:polished_andesite")
        return BlockState("minecraft:andesite")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.polished else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Andesite(polished=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Andesite(polished=True), Andesite()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.polished:
            return EncodedItem("minecraft:polished_andesite", 0)
        return EncodedItem("minecraft:andesite", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self(polished=True), Self()]
