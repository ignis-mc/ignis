"""`EndRod`, ported from Dragonfly `server/block/end_rod.go`.

Go's `flowingWaterDisplacer` comes with liquids.

TODO(world-runtime): UseOnBlock, Model, SideClosed and the drops.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
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
from .cube.axis import Axis
from .cube.face import Face, faces
from .hash import HASH_END_ROD
from .model.end_rod import EndRod as EndRodModel


struct EndRod(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
):
    """A decorative light source that emits white particles."""

    comptime BASE_HASH: UInt64 = HASH_END_ROD
    """Go `hashEndRod`."""
    comptime ModelType = EndRodModel
    """The model type (Go `Model`)."""

    var facing: Face
    """The direction the end rod faces."""

    def __init__(out self, *, facing: Face = Face.DOWN):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var f = self.facing
        if f.axis() != Axis.Y:
            f = f.opposite()
        return BlockState(
            "minecraft:end_rod",
            Properties().with_int("facing_direction", Int32(Int(f))),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return EndRod(facing=Face(Int(hash & 0x7)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for facing in faces():
            out.append(EndRod(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 14

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EndRodModel:
        """Returns the model of the block (Go `Model`)."""
        return EndRodModel(axis=self.facing.axis())

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:end_rod", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
