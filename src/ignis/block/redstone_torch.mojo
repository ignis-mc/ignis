"""`RedstoneTorch`, ported from Dragonfly `server/block/redstone_torch.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, HasLiquidDrops,
RedstoneSource, RedstonePower, RedstoneStrongPower, RedstoneUpdate,
ScheduledTick, the break handler clearing burnout and the drops.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .block import UNKNOWN_FACE
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .cube.face import Face, faces
from .hash import HASH_REDSTONE_TORCH
from .model.empty import Empty as EmptyModel


struct RedstoneTorch(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
):
    """A non-solid block that emits light and redstone power."""

    comptime BASE_HASH: UInt64 = HASH_REDSTONE_TORCH
    """Go `hashRedstoneTorch`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var facing: Face
    """The face the torch is attached to; `UNKNOWN_FACE` stands for standing."""
    var lit: Bool
    """Whether the torch is lit and powering."""

    def __init__(out self, *, facing: Face = Face.DOWN, lit: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.lit = lit

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var face: String
        if self.facing == Face.DOWN:
            face = "top"
        elif self.facing == UNKNOWN_FACE:
            face = "unknown"
        else:
            face = String(self.facing)
        var name = (
            "minecraft:redstone_torch" if self.lit else "minecraft:unlit_redstone_torch"
        )
        return BlockState(
            name, Properties().with_string("torch_facing_direction", face^)
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.lit else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return RedstoneTorch(
            facing=Face(Int(hash & 0x7)), lit=(hash >> 3) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for f in faces():
            var face = UNKNOWN_FACE if f == Face.UP else f
            out.append(RedstoneTorch(facing=face))
            out.append(RedstoneTorch(facing=face, lit=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 7 if self.lit else 0

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:redstone_torch", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
