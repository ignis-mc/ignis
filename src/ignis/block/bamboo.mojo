"""`Bamboo`, ported from Dragonfly `server/block/bamboo.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, BoneMeal, grow, Model,
FlammabilityInfo and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, LightDiffuser, RandomTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .bamboo_leaf_size import BambooLeafSize, bamboo_leaf_sizes
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import AnyBlock, HASH_BAMBOO
from .model.bamboo import Bamboo as BambooModel
from .block import replaceable_with
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face


struct Bamboo(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    LightDiffuser,
    ModelledBlock,
    RandomTicker,
):
    """A woody plant that grows quickly."""

    comptime BASE_HASH: UInt64 = HASH_BAMBOO
    """Go `hashBamboo`."""
    comptime ModelType = BambooModel
    """The model type (Go `Model`)."""

    var ready: Bool
    """Whether the bamboo is ready to grow."""
    var thick: Bool
    """Whether the stalk is thick."""
    var leaf_size: BambooLeafSize
    """The size of the leaves on the bamboo."""

    def __init__(
        out self,
        *,
        ready: Bool = False,
        thick: Bool = False,
        leaf_size: BambooLeafSize = BambooLeafSize.NO_LEAVES,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.ready = ready
        self.thick = thick
        self.leaf_size = leaf_size

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var thickness = "thick" if self.thick else "thin"
        return BlockState(
            "minecraft:bamboo",
            Properties()
            .with_byte("age_bit", UInt8(self.ready))
            .with_string("bamboo_leaf_size", String(self.leaf_size))
            .with_string("bamboo_stalk_thickness", thickness),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            (UInt64(1) if self.ready else UInt64(0))
            | (UInt64(1) if self.thick else UInt64(0)) << 1
            | UInt64(self.leaf_size.uint8()) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Bamboo(
            ready=hash & 0x1 != 0,
            thick=(hash >> 1) & 0x1 != 0,
            leaf_size=BambooLeafSize(Int((hash >> 2) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for ready in [False, True]:
            for thick in [False, True]:
                for leaf_size in bamboo_leaf_sizes():
                    out.append(
                        Bamboo(ready=ready, thick=thick, leaf_size=leaf_size)
                    )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(1, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> BambooModel:
        """Returns the model of the block (Go `Model`)."""
        return BambooModel(thick=self.thick)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 2.5 s."""
        return FuelInfo(2500)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:bamboo", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """May grow when lit (Go `RandomTick`)."""
        if tx.light(pos) >= 9 and tx.rand().int_n(3) == 0:
            _ = _bamboo_grow(self, pos, 1, _bamboo_max_height(pos), tx)


def _bamboo_max_height(pos: Pos) -> Int:
    # Go `Bamboo.maxHeight`.
    var seed = UInt32(3129871) * UInt32(pos.x()) ^ UInt32(116129781) * UInt32(
        pos.z()
    )
    seed *= UInt32(42317861) * seed + 11
    return 12 + Int(seed >> 24) % 5


def _bamboo_grow[
    T: WorldTypes
](b: Bamboo, pos: Pos, amount: Int, max_height: Int, mut tx: World[T]) -> Bool:
    # Go `Bamboo.grow`.
    if not replaceable_with(tx, pos.side(Face.UP), AnyBlock(b)):
        return False
    var height = 1
    while True:
        if not tx.block_as[Bamboo](pos.sub(Pos(0, height, 0))):
            break
        height += 1
        if height >= max_height:
            return False
    var layout = _growth_layout(b, height + amount, amount)
    for i in range(len(layout)):
        tx.set_block(pos.sub(Pos(0, i - amount, 0)), layout[i])
    return True


def _growth_layout(b: Bamboo, new_height: Int, amount: Int) -> List[Bamboo]:
    # Go `Bamboo.growthLayout`.
    var thick = b.thick or new_height >= 4
    var stem = Bamboo(thick=thick)
    var small = Bamboo(thick=thick, leaf_size=BambooLeafSize.SMALL_LEAVES)
    var big = Bamboo(thick=thick, leaf_size=BambooLeafSize.LARGE_LEAVES)
    var out = List[Bamboo]()
    if new_height == 2:
        out.append(small)
    elif new_height == 3:
        out.append(small)
        out.append(small)
    elif new_height == 4:
        out.append(big)
        out.append(small)
        out.append(stem)
        out.append(stem)
    elif new_height > 4:
        out.append(big)
        out.append(big)
        out.append(small)
        for _ in range(min(amount, new_height - 3)):
            out.append(stem)
    return out^
