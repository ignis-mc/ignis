"""`ItemFrame`, ported from Dragonfly `server/block/item_frame.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Item item.Stack` field, Activate, Punch, UseOnBlock,
NeighbourUpdateTick, SideClosed, DecodeNBT, EncodeNBT, Pick, the break handler
and the drops.
"""

from ..world.block import Block, LightDiffuser
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
from .cube.face import Face, faces
from .hash import HASH_ITEM_FRAME
from .model.empty import Empty as EmptyModel


struct ItemFrame(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A block that displays an item."""

    comptime BASE_HASH: UInt64 = HASH_ITEM_FRAME
    """Go `hashItemFrame`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var facing: Face
    """The face of the block the frame is attached to."""
    var rotations: Int
    """The number of times the item has been rotated."""
    var drop_chance: Float64
    """The chance of the item dropping when the frame is punched."""
    var glowing: Bool
    """Whether the frame is a glow item frame."""

    def __init__(
        out self,
        *,
        facing: Face = Face.DOWN,
        rotations: Int = 0,
        drop_chance: Float64 = 0,
        glowing: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The face of the block the frame is attached to.
            rotations: The number of times the item has been rotated.
            drop_chance: The chance of the item dropping when the frame is punched.
            glowing: Whether the frame is a glow item frame.
        """
        self.facing = facing
        self.rotations = rotations
        self.drop_chance = drop_chance
        self.glowing = glowing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return (
            self.hash() == other.hash()
            and self.rotations == other.rotations
            and self.drop_chance == other.drop_chance
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        var name = "minecraft:glow_frame" if self.glowing else "minecraft:frame"
        return BlockState(
            name,
            Properties()
            .with_int("facing_direction", Int32(Int(self.facing.opposite())))
            .with_byte("item_frame_map_bit", 0)
            .with_byte("item_frame_photo_bit", 0),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.glowing else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return ItemFrame(
            facing=Face(Int(hash & 0x7)), glowing=(hash >> 3) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for f in faces():
            out.append(ItemFrame(facing=f, glowing=True))
            out.append(ItemFrame(facing=f, glowing=False))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.25, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

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
        if self.glowing:
            return EncodedItem("minecraft:glow_frame", 0)
        return EncodedItem("minecraft:frame", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self(glowing=True), Self()]
