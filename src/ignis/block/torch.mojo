"""`Torch`, ported from Dragonfly `server/block/torch.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, HasLiquidDrops and the
drops.
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
from .fire_type import FireType, fire_types
from .hash import HASH_TORCH
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable


struct Torch(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    LiquidRemovable,
    ModelledBlock,
):
    """A non-solid blocks that emits light."""

    comptime BASE_HASH: UInt64 = HASH_TORCH
    """Go `hashTorch`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var facing: Face
    """The face the torch is attached to; `UNKNOWN_FACE` stands for standing."""
    var type: FireType
    """The type of fire of the torch."""

    def __init__(
        out self, *, facing: Face = Face.DOWN, type: FireType = FireType.NORMAL
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.type = type

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
        var name = "minecraft:torch"
        if self.type == FireType.SOUL:
            name = "minecraft:soul_torch"
        return BlockState(
            name, Properties().with_string("torch_facing_direction", face^)
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing)) | UInt64(self.type.uint8()) << 3

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Torch(
            facing=Face(Int(hash & 0x7)), type=FireType(Int((hash >> 3) & 0x1))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for f in faces():
            var face = UNKNOWN_FACE if f == Face.UP else f
            out.append(Torch(type=FireType.NORMAL, facing=face))
            out.append(Torch(type=FireType.SOUL, facing=face))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        if self.type == FireType.NORMAL:
            return 14
        return self.type.light_level()

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.type == FireType.SOUL:
            return EncodedItem("minecraft:soul_torch", 0)
        return EncodedItem("minecraft:torch", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in fire_types():
            out.append(Torch(type=v))
        return out^

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True
