"""`DecoratedPot`, ported from Dragonfly `server/block/decorated_pot.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Item item.Stack`, `Decorations [4]PotDecoration`
fields, PotDecoration, InsertItem, ExtractItem, wobble, ProjectileHit, Model,
UseOnBlock, the break handler and the drops.
"""

from minecraft.nbt.nbt import TAG_STRING
from minecraft.nbt.tree import Tag, Tree

from ..world.block import Block, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .block import horizontal_direction
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_DECORATED_POT
from .model.decorated_pot import DecoratedPot as DecoratedPotModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct DecoratedPot(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
):
    """A decorative block that can be crafted from bricks and pottery sherds."""

    comptime BASE_HASH: UInt64 = HASH_DECORATED_POT
    """Go `hashDecoratedPot`."""
    comptime ModelType = DecoratedPotModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the pot faces."""

    def __init__(out self, *, facing: Direction = Direction.NORTH):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:decorated_pot",
            Properties().with_int(
                "direction", Int32(Int(horizontal_direction(self.facing)))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return DecoratedPot(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for facing in directions():
            out.append(DecoratedPot(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> DecoratedPotModel:
        """Returns the model of the block (Go `Model`)."""
        return DecoratedPotModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:decorated_pot", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "DecoratedPot")
        # TODO(world-runtime): the decorations and the item; without
        # decorations every side is a brick.
        var sherds = tag.put_list(root, "sherds", TAG_STRING)
        for _ in range(4):
            _ = tag.append_string(sherds, "minecraft:brick")

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        # TODO(world-runtime): the item and the decorations (sherds).
        return Self(facing=self.facing)

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
