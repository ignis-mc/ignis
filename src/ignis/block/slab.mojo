"""`Slab`, ported from Dragonfly `server/block/slab.go`.

TODO(world-runtime): Instrument, FlammabilityInfo, CanRedstoneWireStepDown,
Model and the drops.
"""

from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .block import Placement, UsableOnBlock, first_replaceable, replaceable_with
from .hash import AnyBlock

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .blackstone import Blackstone
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .end_bricks import EndBricks
from .hash import (
    AnyBlock,
    HASH_BAMBOO_MOSAIC,
    HASH_SLAB,
    hash_block,
    unhash_block,
)
from .model.slab import Slab as SlabModel
from .planks import Planks
from .polished_blackstone_brick import PolishedBlackstoneBrick
from .purpur import Purpur
from .quartz import Quartz
from .register import break_info
from .sandstone import Sandstone
from .slab_type import encode_slab_block, slab_blocks
from .stone import Stone
from .stone_bricks import StoneBricks
from .stone_bricks_type import StoneBricksType
from ..world.block import LiquidDisplacer
from .water import Water


struct Slab(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    UsableOnBlock,
):
    """A half block that allows entities to walk up blocks without jumping."""

    comptime BASE_HASH: UInt64 = HASH_SLAB
    """Go `hashSlab`."""
    comptime ModelType = SlabModel
    """The model type (Go `Model`)."""

    var block: AnyBlock
    """The block the slab is made of."""
    var top: Bool
    """Whether the slab is in the top half of the block."""
    var double: Bool
    """Whether the slab is a double slab."""

    def __init__(
        out self, *, block: AnyBlock, top: Bool = False, double: Bool = False
    ):
        """Creates the block; `block` is required, the other fields default to Go zero values.
        """
        self.block = block
        self.top = top
        self.double = double

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var side = "top" if self.top else "bottom"
        var n = encode_slab_block(self.block, self.double)
        return BlockState(
            String(t"minecraft:{n[0]}{n[1]}"),
            Properties().with_string("minecraft:vertical_half", side),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            hash_block(self.block)
            | (UInt64(1) if self.top else UInt64(0)) << 32
            | (UInt64(1) if self.double else UInt64(0)) << 33
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Slab(
            block=unhash_block(hash & 0xFFFFFFFF),
            top=(hash >> 32) & 0x1 != 0,
            double=(hash >> 33) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for s in slab_blocks():
            out.append(Slab(block=s, double=True))
            out.append(Slab(block=s, top=True, double=True))
            out.append(Slab(block=s, top=True))
            out.append(Slab(block=s))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        var hardness = 2.0
        var blast_resistance = 6.0
        var harvestable = PICKAXE_HARVESTABLE
        var effective = PICKAXE_EFFECTIVE
        var b = self.block
        if (
            b.is_a[Stone]()
            or b.is_a[Sandstone]()
            or b.is_a[Quartz]()
            or b.is_a[Purpur]()
            or b.is_a[Blackstone]()
            or b.is_a[PolishedBlackstoneBrick]()
        ):
            pass
        elif b.is_a[EndBricks]():
            hardness = 3
        elif case .Some(s) = b.get[StoneBricks]():
            if s.type == StoneBricksType.MOSSY:
                hardness = 1.5
        elif case .Some(info) = break_info(b.kind, b.state):
            hardness = info.hardness
            blast_resistance = info.blast_resistance
            harvestable = info.harvestable
            effective = info.effective
        return new_break_info(
            hardness, harvestable, effective
        ).with_blast_resistance(blast_resistance)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 15 if self.double else 0

    def model(self) -> SlabModel:
        """Returns the model of the block (Go `Model`)."""
        return SlabModel(double=self.double, top=self.top)

    def use_on_block[
        T: WorldTypes
    ](
        self,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: Rotation,
        mut tx: World[T],
    ) -> List[Placement]:
        """Places a top or bottom slab, or completes a half slab of the same
        kind into a double slab (Go `UseOnBlock`)."""
        var br = tx.block_registry()
        if not self.double:
            var rid = tx.block(pos)
            if br[].kind(rid) == Self.BASE_HASH:
                var clicked = Self.from_hash(br[].state_hash(rid))
                if (
                    not clicked.double
                    and clicked.block == self.block
                    and (
                        (face == Face.UP and not clicked.top)
                        or (face == Face.DOWN and clicked.top)
                    )
                ):
                    var d = clicked.copy()
                    d.double = True
                    return [
                        Placement(
                            pos, AnyBlock(Self.BASE_HASH, d.hash()), False
                        )
                    ]
            var side = pos.side(face)
            var srid = tx.block(side)
            if br[].kind(srid) == Self.BASE_HASH and not replaceable_with(
                tx, pos, AnyBlock(Self.BASE_HASH, self.hash())
            ):
                var s = Self.from_hash(br[].state_hash(srid))
                if not s.double and s.block == self.block:
                    var d = s.copy()
                    d.double = True
                    return [
                        Placement(
                            side, AnyBlock(Self.BASE_HASH, d.hash()), False
                        )
                    ]
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var f = at.value()[1]
        var b = self.copy()
        if f == Face.DOWN or (click.y() > 0.5 and f != Face.UP):
            b.top = True
        return [
            Placement(at.value()[0], AnyBlock(Self.BASE_HASH, b.hash()), False)
        ]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        var n = encode_slab_block(self.block, False)
        return EncodedItem(String(t"minecraft:{n[0]}{n[1]}"), 0)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info of the block it is made of (Go `FuelInfo`)."""
        if case .Some(p) = self.block.get[Planks]():
            return p.fuel_info()
        if self.block.kind == HASH_BAMBOO_MOSAIC:
            # Go `BambooMosaic.FuelInfo`.
            return FuelInfo(15000)
        return FuelInfo()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in slab_blocks():
            out.append(Slab(block=v))
        return out^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water of depth 8 unless double (Go `CanDisplace`)."""
        if case .Some(w) = b.get[Water]():
            return not self.double and w.depth == 8
        return False

    def side_closed[
        T: WorldTypes
    ](self, pos: Pos, side: Pos, mut tx: World[T]) -> Bool:
        """Closed below a bottom slab (Go `SideClosed`)."""
        return not self.top and side.y() == pos.y() - 1
