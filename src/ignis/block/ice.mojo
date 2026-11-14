"""`Ice`, ported from Dragonfly `server/block/ice.go`.

TODO(world-runtime): Friction, the break handler turning it into water and the
drops.
"""

from ..world.block import Block, LightDiffuser, RandomTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    new_break_info,
)
from .hash import HASH_ICE
from .model.solid import Solid as SolidModel
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .water import Water


struct Ice(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    RandomTicker,
):
    """A solid block similar to packed ice."""

    comptime BASE_HASH: UInt64 = HASH_ICE
    """Go `hashIce`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `Ice{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:ice")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Ice()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Ice()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 2

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:ice", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Melts next to bright block light (Go `RandomTick`)."""
        for f in range(6):
            if tx.block_light(pos.side(Face(f))) > 11:
                # Go `melt`.
                if tx.dimension().water_evaporates():
                    tx.set_block_runtime_id(
                        pos, tx.block_registry()[].air_runtime_id()
                    )
                    return
                tx.set_block(pos, Water(still=True, depth=8))
                return
