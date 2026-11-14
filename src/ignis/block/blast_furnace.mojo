"""`BlastFurnace`, ported from Dragonfly `server/block/blast_furnace.go`.

TODO(world-runtime): the `*smelter` (smelter.go: inventory, fuel, progress,
Experience and the XP the break info drops), NewFurnace, Tick, Activate,
UseOnBlock, the break handler dropping the inventory and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..world.block import Block, LightEmitter, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_BLAST_FURNACE
from .model.solid import Solid as SolidModel


struct BlastFurnace(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightEmitter,
    ModelledBlock,
    NBTer,
):
    """A block that smelts ores, raw metals, iron and gold armour and tools, similar to a
    furnace, but at twice the speed."""

    comptime BASE_HASH: UInt64 = HASH_BLAST_FURNACE
    """Go `hashBlastFurnace`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the front of the block faces."""
    var lit: Bool
    """Whether the block is lit."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, lit: Bool = False
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the front of the block faces.
            lit: Whether the block is lit.
        """
        self.facing = facing
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
        var name = (
            "minecraft:lit_blast_furnace" if self.lit else "minecraft:blast_furnace"
        )
        return BlockState(
            name,
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.lit else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return BlastFurnace(
            facing=Direction(Int(hash & 0x3)), lit=(hash >> 2) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for face in directions():
            out.append(BlastFurnace(facing=face))
            out.append(BlastFurnace(facing=face, lit=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(3.5, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return 13 if self.lit else 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:blast_furnace", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        # TODO(world-runtime): the smelter's durations, experience and
        # inventory; these are a new smelter's.
        _ = tag.put_short(root, "BurnTime", 0)
        _ = tag.put_short(root, "CookTime", 0)
        _ = tag.put_short(root, "BurnDuration", 0)
        _ = tag.put_short(root, "StoredXPInt", 0)
        _ = tag.put_list(root, "Items")
        _ = tag.put_string(root, "id", "BlastFurnace")

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        # TODO(world-runtime): the smelter's state; Go keeps only the
        # facing and lit state of the block.
        return Self(facing=self.facing, lit=self.lit)
