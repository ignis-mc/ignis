"""`Bed`, ported from Dragonfly `server/block/bed.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Sleeper` entity handle, Model, SideClosed,
UseOnBlock, Activate, EntityLand, bounce, NeighbourUpdateTick, head, the break
handler waking the sleeper and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_uint8
from ..item.colour import Colour, colours
from ..item.item import MaxCounter
from ..world.block import Block, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item, ItemHasher
from .block import horizontal_direction
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_BED
from .model.bed import Bed as BedModel


struct Bed(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ItemHasher,
    LightDiffuser,
    MaxCounter,
    ModelledBlock,
    NBTer,
):
    """A block that allows players to sleep to set their spawn point and skip the night.
    """

    comptime BASE_HASH: UInt64 = HASH_BED
    """Go `hashBed`."""
    comptime ModelType = BedModel
    """The model type (Go `Model`)."""

    var colour: Colour
    """The colour of the bed, kept in NBT."""
    var facing: Direction
    """The direction the head of the bed faces."""
    var head: Bool
    """Whether this is the head of the bed."""
    var occupied: Bool
    """Whether someone sleeps in the bed."""

    def __init__(
        out self,
        *,
        colour: Colour = Colour.WHITE,
        facing: Direction = Direction.NORTH,
        head: Bool = False,
        occupied: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.colour = colour
        self.facing = facing
        self.head = head
        self.occupied = occupied

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash() and self.colour == other.colour

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:bed",
            Properties()
            .with_int(
                "direction", Int32(Int(horizontal_direction(self.facing)))
            )
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
        return Bed(
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
                    out.append(Bed(facing=d, head=head, occupied=occupied))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.2, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> BedModel:
        """Returns the model of the block (Go `Model`)."""
        return BedModel()

    def max_count(self) -> Int:
        """Returns the maximum stack count (Go `MaxCount`)."""
        return 1

    def item_hash(self) -> UInt64:
        """Returns the item hash: the state hash with the colour, which Go
        keeps in the block entity, in bits 8 to 11."""
        return self.hash() | UInt64(self.colour.uint8()) << 8

    @staticmethod
    def from_item_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its `item_hash`."""
        var b = Self.from_hash(hash & 0xFF)
        b.colour = Colour(Int((hash >> 8) & 0xF))
        return b^

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:bed", Int16(self.colour.uint8()))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for c in colours():
            out.append(Self(colour=c))
        return out^

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "Bed")
        _ = tag.put_byte(root, "color", self.colour.uint8())

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var c = Int(get_uint8(tag, root, "color"))
        if c > 15:
            # Go indexes Colours() and panics.
            raise Error(t"bed: invalid colour {c}")
        var b = self.copy()
        b.colour = Colour(c)
        return b^
