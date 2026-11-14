"""`Chest`, ported from Dragonfly `server/block/chest.go`.

Differences from Go:

- The inventory and viewers live with the world's block entity; a paired
  chest keeps its own 27 slots there and the window of a pair is built
  from both halves (`chest_halves`), left half first as in Go `pair`.
  Viewers are registered on both halves, so a change in either reaches
  every viewer (the right half's slots shift by 27).
- Go pairs lazily in `tryPair` when the inventory is first asked for;
  here `chest_halves` checks the pair whenever the window opens and
  unpairs a chest whose other half is gone or points elsewhere.
- Breaking one half closes the windows of those viewing the pair; Go leaves
  them looking at the old double inventory.
- Go's `sourceWaterDisplacer` comes with liquids (block-behaviour).
- `FlammabilityInfo` is not ported.
"""

from minecraft.nbt.nbt import TAG_INT
from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_string
from ..item.inventory.inventory import Inventory
from ..item.smelting_info import Fuel, FuelInfo
from ..mgl64 import Vec3
from ..world.block import Block, Container, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_set import encode_block_nbt
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from ..world.sound.block import ChestClose, ChestOpen
from ..world.viewer import BLOCK_ACTION_CLOSE, BLOCK_ACTION_OPEN
from ..world.world import World, WorldTypes
from .block import (
    Activatable,
    BreakHandler,
    Openable,
    Placement,
    UsableOnBlock,
    UseContext,
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
from .cube.direction import Direction, directions
from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from .hash import AnyBlock, HASH_CHEST
from .model.chest import Chest as ChestModel


struct Chest(
    Activatable,
    Block,
    BreakHandler,
    Breakable,
    Container,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    NBTer,
    Openable,
    UsableOnBlock,
):
    """A container block which may be used to store items."""

    comptime BASE_HASH: UInt64 = HASH_CHEST
    """Go `hashChest`."""
    comptime ModelType = ChestModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the chest faces."""
    var custom_name: String
    """The custom name of the block, shown in its window."""
    var paired: Bool
    """The chest is half of a double chest (Go `paired`)."""
    var pair_x: Int
    """The x of the other half (Go `pairX`)."""
    var pair_z: Int
    """The z of the other half (Go `pairZ`)."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        custom_name: String = String(),
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.custom_name = custom_name
        self.paired = False
        self.pair_x = 0
        self.pair_z = 0

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return (
            self.hash() == other.hash()
            and self.custom_name == other.custom_name
            and self.paired == other.paired
            and self.pair_x == other.pair_x
            and self.pair_z == other.pair_z
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:chest",
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Chest(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for facing in directions():
            out.append(Chest(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(2.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> ChestModel:
        """Returns the model of the block (Go `Model`)."""
        return ChestModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:chest", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def inventory_size(self) -> Int:
        """Returns the 27 slots one chest stores (Go `inventory.New(27)`)."""
        return 27

    def pair_pos(self, pos: Pos) -> Pos:
        """Returns where the other half is (Go `pairPos`)."""
        return Pos(self.pair_x, pos.y(), self.pair_z)

    def opened[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Opens the lid of both halves (Go `open`)."""
        for v in tx.viewers(pos.vec3()):
            if self.paired:
                tx.viewer(v).view_block_action(
                    self.pair_pos(pos), BLOCK_ACTION_OPEN
                )
            tx.viewer(v).view_block_action(pos, BLOCK_ACTION_OPEN)
        tx.play_sound(pos.vec3_centre(), ChestOpen())

    def closed[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Closes the lid of both halves (Go `close`)."""
        for v in tx.viewers(pos.vec3()):
            if self.paired:
                tx.viewer(v).view_block_action(
                    self.pair_pos(pos), BLOCK_ACTION_CLOSE
                )
            tx.viewer(v).view_block_action(pos, BLOCK_ACTION_CLOSE)
        tx.play_sound(pos.vec3_centre(), ChestClose())

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens the chest unless a block that diffuses light covers it or
        its pair (Go `Activate`)."""
        var br = tx.block_registry()
        if self.paired:
            var up = tx.block(self.pair_pos(pos).side(Face.UP))
            if br[].filtering_block(up) > 2:
                return False
        if br[].filtering_block(tx.block(pos.side(Face.UP))) <= 2:
            ctx.open_container = True
        return True

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
        """Places a chest facing the user, paired with a chest facing the
        same way to its left or right (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var p = at.value()[0]
        var c = Chest(facing=user.direction().opposite())
        for d in [c.facing.rotate_left(), c.facing.rotate_right()]:
            var pp = p.side(d.face())
            if case .Some(pair) = tx.block_as[Chest](pp):
                if c.can_pair(p, pp, pair):
                    var a = c.paired_with(pp)
                    var b = pair.paired_with(p)
                    var out = List[Placement]()
                    out.append(
                        Placement(
                            p,
                            AnyBlock(Self.BASE_HASH, a.hash()),
                            nbt=encode_block_nbt(a),
                        )
                    )
                    out.append(
                        Placement(
                            pp,
                            AnyBlock(Self.BASE_HASH, b.hash()),
                            nbt=encode_block_nbt(b),
                            update=True,
                        )
                    )
                    return out^
        return [
            Placement(
                p, AnyBlock(Self.BASE_HASH, c.hash()), nbt=encode_block_nbt(c)
            )
        ]

    def can_pair(self, pos: Pos, pair_pos: Pos, pair: Chest) -> Bool:
        """Reports whether `pair` at `pair_pos` can be the other half of
        this chest at `pos` (Go's checks in `pair`)."""
        if self.facing != pair.facing:
            return False
        return not pair.paired or (
            pair.pair_x == pos.x() and pair.pair_z == pos.z()
        )

    def paired_with(self, pair_pos: Pos) -> Chest:
        """Returns the chest paired with the chest at `pair_pos`."""
        var c = self.copy()
        c.paired = True
        c.pair_x = pair_pos.x()
        c.pair_z = pair_pos.z()
        return c^

    def unpaired(self) -> Chest:
        """Returns the chest without its pair (Go `unpair`)."""
        var c = self.copy()
        c.paired = False
        c.pair_x = 0
        c.pair_z = 0
        return c^

    def on_break[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], harvest: Bool):
        """Unpairs the other half and drops the contents (Go's break
        handler)."""
        if self.paired:
            var pp = self.pair_pos(pos)
            if case .Some(pair) = tx.block_as[Chest](pp):
                if pair.facing == self.facing and pair.paired:
                    tx.close_container_viewers(pp)
                    tx.set_viewer_slot_offset(pp, 0)
                    tx.set_block(pp, pair.unpaired())
        tx.close_container_viewers(pos)
        drop_contents(pos, tx, pos.vec3_centre())

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`); the world adds the
        `Items`."""
        _ = tag.put_list(root, "Items")
        _ = tag.put_string(root, "id", "Chest")
        if self.custom_name.byte_length() != 0:
            _ = tag.put_string(root, "CustomName", self.custom_name)
        if self.paired:
            _ = tag.put_int(root, "pairx", Int32(self.pair_x))
            _ = tag.put_int(root, "pairz", Int32(self.pair_z))

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var c = Self(
            facing=self.facing, custom_name=get_string(tag, root, "CustomName")
        )
        var px = tag.get(root, "pairx")
        var pz = tag.get(root, "pairz")
        if px and pz:
            if (
                tag.type_of(px.value()) == TAG_INT
                and tag.type_of(pz.value()) == TAG_INT
            ):
                c.paired = True
                c.pair_x = Int(tag.as_int(px.value()))
                c.pair_z = Int(tag.as_int(pz.value()))
        return c^


def chest_halves[
    T: WorldTypes
](pos: Pos, mut tx: World[T]) -> Optional[Tuple[Pos, Pos]]:
    """Returns the left and right half of the double chest at `pos`, or None
    for a single chest; a chest whose pair is gone is unpaired (Go
    `tryPair`), and a pair only one half records is completed."""
    var found = tx.block_as[Chest](pos)
    if not found:
        return None
    var c = found.value()
    if not c.paired:
        return None
    var pp = c.pair_pos(pos)
    var pair = tx.block_as[Chest](pp)
    if not pair or not c.can_pair(pos, pp, pair.value()):
        tx.set_block(pos, c.unpaired())
        tx.set_viewer_slot_offset(pos, 0)
        return None
    if not pair.value().paired:
        tx.set_block(pp, pair.value().paired_with(pos))
    # Go `pair`: the half on this chest's right is the left of the window.
    var left = pos
    var right = pp
    if pos.side(c.facing.rotate_right().face()) == pp:
        left = pp
        right = pos
    tx.set_viewer_slot_offset(left, 0)
    tx.set_viewer_slot_offset(right, 27)
    return (left, right)
