"""`Furnace`, ported from Dragonfly `server/block/furnace.go`.

The smelting (Go's embedded `*smelter`) is `block/smelter.mojo`: the
inventory lives with the world's block entity, the durations are NBT fields
of the value. The experience the break info drops (Go `withXPDropRange`)
is kept but not dropped: experience orbs are not ported.
"""

from minecraft.nbt.tree import Tag, Tree

from ..mgl64 import Vec3
from ..world.block import Block, Container, LightEmitter, NBTer, TickerBlock
from ..world.block_set import encode_block_nbt
from ..world.sound.block import FurnaceCrackle
from ..world.world import World, WorldTypes
from .block import (
    Activatable,
    BreakHandler,
    Placement,
    UsableOnBlock,
    UseContext,
    User,
    first_replaceable,
)
from .container import drop_contents
from .cube.face import Face
from .cube.pos import Pos
from .smelter import SMELT_ANY, Smelter, tick_smelting
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import AnyBlock, HASH_FURNACE
from .model.solid import Solid as SolidModel


struct Furnace(
    Activatable,
    Block,
    BreakHandler,
    Breakable,
    Container,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightEmitter,
    ModelledBlock,
    NBTer,
    TickerBlock,
    UsableOnBlock,
):
    """A utility block used for the smelting of blocks and items."""

    comptime BASE_HASH: UInt64 = HASH_FURNACE
    """Go `hashFurnace`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the front of the block faces."""
    var lit: Bool
    """Whether the block is lit."""
    var smelter: Smelter
    """The smelting progress (Go's `*smelter` durations)."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, lit: Bool = False
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.lit = lit
        self.smelter = Smelter()

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash() and self.smelter == other.smelter

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = "minecraft:lit_furnace" if self.lit else "minecraft:furnace"
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
        return Furnace(
            facing=Direction(Int(hash & 0x3)), lit=(hash >> 2) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for face in directions():
            out.append(Furnace(facing=face))
            out.append(Furnace(facing=face, lit=True))
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
        return EncodedItem("minecraft:furnace", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`); the world adds the
        `Items`."""
        self.smelter.encode(tag, root)
        _ = tag.put_list(root, "Items")
        _ = tag.put_string(root, "id", "Furnace")

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var f = Self(facing=self.facing, lit=self.lit)
        f.smelter = Smelter.decode(tag, root)
        return f^

    def inventory_size(self) -> Int:
        """Returns the input, fuel and product slots (Go `ContainerSize`)."""
        return 3

    def tick[
        T: WorldTypes
    ](self, current_tick: Int64, pos: Pos, mut tx: World[T]):
        """Smelts (Go `Tick`), crackling now and then while lit."""
        if self.lit and tx.global_rand().float64() <= 0.016:
            tx.play_sound(pos.vec3_centre(), FurnaceCrackle())
        var f = self.copy()
        var lit = tick_smelting(
            f.smelter, pos, tx, 10000, 100, self.lit, SMELT_ANY
        )
        if lit != self.lit:
            f.lit = lit
            tx.set_block(pos, f)
        elif f.smelter != self.smelter:
            tx.set_block_entity_nbt(pos, encode_block_nbt(f), notify=False)

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens the window (Go `Activate`)."""
        ctx.open_container = True
        return True

    def use_on_block[
        T: WorldTypes
    ](
        self,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: User,
        mut tx: World[T],
    ) -> List[Placement]:
        """Places it facing the user (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var f = Self(facing=user.direction().opposite())
        return [Placement(at.value()[0], AnyBlock(Self.BASE_HASH, f.hash()))]

    def on_break[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], harvest: Bool):
        """Drops the contents (Go's break handler)."""
        tx.close_container_viewers(pos)
        drop_contents(pos, tx, pos.vec3())
