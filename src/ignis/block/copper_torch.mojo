"""`CopperTorch`, ported from Dragonfly `server/block/copper_torch.go`.

TODO(world-runtime): UseOnBlock and the drops.
"""

from ..world.block import (
    Block,
    LightDiffuser,
    LightEmitter,
    NeighbourUpdateTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .block import UNKNOWN_FACE, face_solid_at, is_air
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .cube.face import Face, faces
from .hash import HASH_COPPER_TORCH
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable
from ..world.world import World, WorldTypes
from .cube.pos import Pos


struct CopperTorch(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    LiquidRemovable,
    ModelledBlock,
    NeighbourUpdateTicker,
):
    """A non-solid block that emits light."""

    comptime BASE_HASH: UInt64 = HASH_COPPER_TORCH
    """Go `hashCopperTorch`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var facing: Face
    """The face the torch is attached to; `UNKNOWN_FACE` stands for standing."""

    def __init__(out self, *, facing: Face = Face.DOWN):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing

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
        return BlockState(
            "minecraft:copper_torch",
            Properties().with_string("torch_facing_direction", face^),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return CopperTorch(facing=Face(Int(hash & 0x7)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for face in faces():
            if face == Face.UP:
                out.append(CopperTorch(facing=UNKNOWN_FACE))
            else:
                out.append(CopperTorch(facing=face))
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

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:copper_torch", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks when the block it is attached to has no solid face (Go
        `NeighbourUpdateTick`)."""
        var side = pos.side(self.facing)
        if not face_solid_at(tx, side, self.facing.opposite()):
            break_block(self, pos, tx)
