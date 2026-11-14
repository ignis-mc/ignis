"""`Smoker`, ported from Dragonfly `server/block/smoker.go`.

TODO(world-runtime): the `*smelter` (smelter.go: inventory, fuel, progress,
Experience, the XP the break info drops), NewFurnace, Tick, Activate,
UseOnBlock, the break handler dropping the inventory and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from minecraft.nbt.tree import Tag, Tree

from ..world.block import Block, LightEmitter, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_SMOKER
from .model.solid import Solid as SolidModel


struct Smoker(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    LightEmitter,
    ModelledBlock,
    NBTer,
):
    """A type of furnace that cooks food items, similar to a furnace, but twice as fast.
    """

    comptime BASE_HASH: UInt64 = HASH_SMOKER
    """Go `hashSmoker`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the front of the block faces."""
    var lit: Bool
    """Whether the block is lit."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, lit: Bool = False
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.lit = lit

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = "minecraft:lit_smoker" if self.lit else "minecraft:smoker"
        return BlockState(
            name,
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.lit else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Smoker(
            facing=Direction(Int(hash & 0x3)), lit=(hash >> 2) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for face in directions():
            out.append(Smoker(facing=face))
            out.append(Smoker(facing=face, lit=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(3.5, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 13 if self.lit else 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:smoker", 0)

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the NBT (Go `EncodeNBT`)."""
        # The smelter is not ported: Go writes a new smoker's (idle, empty).
        _ = tag.put_short(root, "BurnTime", 0)
        _ = tag.put_short(root, "CookTime", 0)
        _ = tag.put_short(root, "BurnDuration", 0)
        _ = tag.put_short(root, "StoredXPInt", 0)
        _ = tag.put_list(root, "Items")
        _ = tag.put_string(root, "id", "Smoker")

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Decodes the NBT (Go `DecodeNBT`); the smelter is not ported."""
        return self

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
