"""`StrawBed`, ported from Dragonfly `server/block/straw_bed.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Sleeper` entity handle, Model, SideClosed,
UseOnBlock, Activate, EntityLand, bounce, NeighbourUpdateTick, head, the break
handler waking the sleeper and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..item.item import MaxCounter
from ..world.block import Block, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    HOE_EFFECTIVE,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_STRAW_BED
from .model.bed import Bed as BedModel


struct StrawBed(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    MaxCounter,
    ModelledBlock,
    NBTer,
):
    """A bed made of straw."""

    comptime BASE_HASH: UInt64 = HASH_STRAW_BED
    """Go `hashStrawBed`."""
    comptime ModelType = BedModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the head of the bed faces."""
    var head: Bool
    """Whether this is the head of the bed."""
    var occupied: Bool
    """Whether someone sleeps in the bed."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        head: Bool = False,
        occupied: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.head = head
        self.occupied = occupied

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:straw_bed",
            Properties()
            .with_string("minecraft:cardinal_direction", String(self.facing))
            .with_byte("occupied_bit", UInt8(self.occupied))
            .with_byte("head_piece_bit", UInt8(self.head)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.head else UInt64(0)) << 2
            | (UInt64(1) if self.occupied else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return StrawBed(
            facing=Direction(Int(hash & 0x3)),
            head=(hash >> 2) & 0x1 != 0,
            occupied=(hash >> 3) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for d in directions():
            for head in [False, True]:
                for occupied in [False, True]:
                    out.append(StrawBed(facing=d, head=head, occupied=occupied))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            0.2, ALWAYS_HARVESTABLE, HOE_EFFECTIVE
        ).with_blast_resistance(0.2)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> BedModel:
        """Returns the model of the block (Go `Model`)."""
        return BedModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:straw_bed", 0)

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 16

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes no NBT (Go `EncodeNBT`)."""
        pass

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the bed unchanged (Go `DecodeNBT`)."""
        return self

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
