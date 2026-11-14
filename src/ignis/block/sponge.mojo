"""`Sponge`, ported from Dragonfly `server/block/sponge.go`.

TODO(world-runtime): UseOnBlock and the drops.
"""

from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block, NeighbourUpdateTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .hash import AnyBlock, HASH_SPONGE
from .model.solid import Solid as SolidModel
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .water import Water
from ..world.particle.block import BlockBreak


struct Sponge(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    NeighbourUpdateTicker,
    Smeltable,
):
    """A block that can be used to remove water around itself when placed."""

    comptime BASE_HASH: UInt64 = HASH_SPONGE
    """Go `hashSponge`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var wet: Bool
    """Whether the sponge is wet."""

    def __init__(out self, *, wet: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.wet = wet

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.wet:
            return BlockState("minecraft:wet_sponge")
        return BlockState("minecraft:sponge")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.wet else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Sponge(wet=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Sponge(wet=True), Sponge()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.6, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.wet:
            return EncodedItem("minecraft:wet_sponge", 0)
        return EncodedItem("minecraft:sponge", 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        if self.wet:
            return SmeltInfo(Stack(Sponge(), 1), 0.15)
        return SmeltInfo()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Sponge(wet=True), Sponge()]

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Absorbs water around it (Go `NeighbourUpdateTick`)."""
        if not self.wet:
            if _absorb_water(pos, tx) > 0:
                tx.set_block(pos, Sponge(wet=True))
                tx.add_particle(
                    pos.vec3_centre(),
                    BlockBreak(block=AnyBlock(Water(depth=1))),
                )


def _absorb_water[T: WorldTypes](pos: Pos, mut tx: World[T]) -> Int:
    # Go `Sponge.absorbWater`: removes up to 65 water blocks (in batches of
    # a block's neighbours) within 7 blocks.
    var queue = List[Tuple[Pos, Int]]()
    queue.append((pos, 0))
    var qi = 0
    var replaced = 0
    var br = tx.block_registry()
    while replaced < 65:
        if qi == len(queue):
            break
        var next = queue[qi]
        qi += 1
        for neighbour in next[0].neighbours(tx.range()):
            if case .Some(l) = tx.liquid(neighbour):
                if br[].is_block[Water](l):
                    tx.remove_liquid(neighbour)
                    replaced += 1
                    if next[1] < 7:
                        queue.append((neighbour, next[1] + 1))
    return replaced
