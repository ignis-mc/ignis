"""`Barrel`, ported from Dragonfly `server/block/barrel.go`.

The inventory and viewers live with the world's block entity (see
`block/container.mojo`). `FlammabilityInfo` is not ported.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_string
from ..item.smelting_info import Fuel, FuelInfo
from ..mgl64 import Vec3
from ..world.block import Block, Container, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from ..world.sound.block import BarrelClose, BarrelOpen
from ..world.world import World, WorldTypes
from .block import (
    Activatable,
    BreakHandler,
    Openable,
    Placement,
    UsableOnBlock,
    UseContext,
    User,
    calculate_face,
    first_replaceable,
)
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .container import drop_contents
from .cube.face import Face
from .cube.pos import Pos
from .hash import AnyBlock, HASH_BARREL
from .model.solid import Solid as SolidModel


struct Barrel(
    Activatable,
    Block,
    BreakHandler,
    Breakable,
    Container,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    NBTer,
    Openable,
    UsableOnBlock,
):
    """A fisherman's job site block, used to store items."""

    comptime BASE_HASH: UInt64 = HASH_BARREL
    """Go `hashBarrel`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var facing: Face
    """The direction the barrel faces."""
    var open: Bool
    """Whether the barrel is open."""
    var custom_name: String
    """The custom name of the block, shown in its window."""

    def __init__(
        out self,
        *,
        facing: Face = Face.DOWN,
        open: Bool = False,
        custom_name: String = String(),
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.open = open
        self.custom_name = custom_name

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return (
            self.hash() == other.hash()
            and self.custom_name == other.custom_name
        )

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:barrel",
            Properties()
            .with_byte("open_bit", UInt8(self.open))
            .with_int("facing_direction", Int32(Int(self.facing))),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.open else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Barrel(facing=Face(Int(hash & 0x7)), open=(hash >> 3) & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for i in range(6):
            out.append(Barrel(facing=Face(i)))
            out.append(Barrel(facing=Face(i), open=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(2.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:barrel", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def inventory_size(self) -> Int:
        """Returns the barrel's 27 slots (Go `ContainerSize`)."""
        return 27

    def opened[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Opens the barrel (Go `open`)."""
        var b = self.copy()
        b.open = True
        tx.play_sound(pos.vec3_centre(), BarrelOpen())
        tx.set_block(pos, b)

    def closed[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Closes the barrel (Go `close`)."""
        var b = self.copy()
        b.open = False
        tx.play_sound(pos.vec3_centre(), BarrelClose())
        tx.set_block(pos, b)

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens the barrel's window (Go `Activate`)."""
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
        """Places the barrel facing the user (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var p = at.value()[0]
        var b = Barrel(facing=calculate_face(user, p))
        return [Placement(p, AnyBlock(Self.BASE_HASH, b.hash()))]

    def on_break[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], harvest: Bool):
        """Drops the contents (Go's break handler)."""
        tx.close_container_viewers(pos)
        drop_contents(pos, tx, pos.vec3())

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`); the world adds the
        `Items`."""
        _ = tag.put_list(root, "Items")
        _ = tag.put_string(root, "id", "Barrel")
        if self.custom_name.byte_length() != 0:
            _ = tag.put_string(root, "CustomName", self.custom_name)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`,
        which does not keep `Open`)."""
        return Self(
            facing=self.facing, custom_name=get_string(tag, root, "CustomName")
        )
