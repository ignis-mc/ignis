"""`Hopper`, ported from Dragonfly `server/block/hopper.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

The inventory and viewers live with the world's block entity. Go keeps
`CollectCooldown` only in the value; Ignis rebuilds the value from its NBT,
so a running collect cooldown is written as `CollectCooldown`.
`RedstoneUpdate` is not ported (Dragonfly v0.11.6 has no redstone for it
either: `Powered` only changes through the block state).
"""

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_int32, get_string
from ..item.stack import Stack
from ..item.inventory.inventory import Inventory
from ..mgl64 import Vec3
from ..world.block import Block, Container, LightDiffuser, NBTer, TickerBlock
from ..world.block_set import encode_block_nbt
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
from .container import (
    container_positions,
    drop_contents,
    read_container,
    write_container,
)
from .cube.pos import Pos
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.face import Face, faces
from .hash import HASH_HOPPER
from .model.hopper import Hopper as HopperModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct Hopper(
    Activatable,
    Block,
    BreakHandler,
    Breakable,
    Container,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
    TickerBlock,
    UsableOnBlock,
):
    """A block used to collect item entities directly above it, as well as to transfer items into
    and out of other containers."""

    comptime BASE_HASH: UInt64 = HASH_HOPPER
    """Go `hashHopper`."""
    comptime ModelType = HopperModel
    """The model type (Go `Model`)."""

    var facing: Face
    """The direction the hopper faces."""
    var powered: Bool
    """Whether the hopper is powered by redstone, which stops it transferring items."""
    var custom_name: String
    """The custom name of the block, shown in its window."""
    var transfer_cooldown: Int
    """The ticks until the hopper may transfer items again."""
    var collect_cooldown: Int
    """The ticks until the hopper may collect items again."""

    def __init__(
        out self,
        *,
        facing: Face = Face.DOWN,
        powered: Bool = False,
        custom_name: String = String(),
        transfer_cooldown: Int = 0,
        collect_cooldown: Int = 0,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.powered = powered
        self.custom_name = custom_name
        self.transfer_cooldown = transfer_cooldown
        self.collect_cooldown = collect_cooldown

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return (
            self.hash() == other.hash()
            and self.custom_name == other.custom_name
            and self.transfer_cooldown == other.transfer_cooldown
            and self.collect_cooldown == other.collect_cooldown
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:hopper",
            Properties()
            .with_int("facing_direction", Int32(Int(self.facing)))
            .with_bool("toggle_bit", self.powered),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.powered else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Hopper(
            facing=Face(Int(hash & 0x7)), powered=(hash >> 3) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for f in faces():
            out.append(Hopper(facing=f))
            out.append(Hopper(facing=f, powered=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            3, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(4.8)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> HopperModel:
        """Returns the model of the block (Go `Model`)."""
        return HopperModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:hopper", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`); the world adds the
        `Items`."""
        _ = tag.put_list(root, "Items")
        _ = tag.put_int(root, "TransferCooldown", Int32(self.transfer_cooldown))
        _ = tag.put_string(root, "id", "Hopper")
        if self.custom_name.byte_length() != 0:
            _ = tag.put_string(root, "CustomName", self.custom_name)
        if self.collect_cooldown > 0:
            _ = tag.put_int(
                root, "CollectCooldown", Int32(self.collect_cooldown)
            )

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        return Self(
            facing=self.facing,
            powered=self.powered,
            custom_name=get_string(tag, root, "CustomName"),
            transfer_cooldown=Int(get_int32(tag, root, "TransferCooldown")),
            collect_cooldown=Int(get_int32(tag, root, "CollectCooldown")),
        )

    def inventory_size(self) -> Int:
        """Returns the hopper's 5 slots (Go `ContainerSize`)."""
        return 5

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens the hopper's window (Go `Activate`)."""
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
        """Places the hopper pointing away from the clicked face, down when
        placed on top (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var h = Hopper()
        if face != Face.DOWN:
            h.facing = face.opposite()
        return [Placement(at.value()[0], AnyBlock(Self.BASE_HASH, h.hash()))]

    def on_break[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], harvest: Bool):
        """Drops the contents (Go's break handler)."""
        tx.close_container_viewers(pos)
        drop_contents(pos, tx, pos.vec3())

    def tick[
        T: WorldTypes
    ](self, current_tick: Int64, pos: Pos, mut tx: World[T]):
        """Counts down the cooldowns and moves one item out and one in every
        8 ticks (Go `Tick`)."""
        var h = self.copy()
        var cooldown_changed = h.transfer_cooldown > 0 or h.collect_cooldown > 0
        if h.transfer_cooldown > 0:
            h.transfer_cooldown -= 1
        if h.collect_cooldown > 0:
            h.collect_cooldown -= 1
        if not h.powered and h.transfer_cooldown <= 0:
            var found = tx.inventory(pos)
            if found:
                var inv = found.value().copy()
                var inserted = h._insert_item(inv, pos, tx)
                var extracted = h._extract_item(inv, pos, tx)
                if inserted or extracted:
                    tx.set_inventory(pos, inv^)
                    h.transfer_cooldown = 8
                    tx.set_block(pos, h)
                    return
        if cooldown_changed:
            # Go `SetBlockEntity`: no block update.
            tx.set_block_entity_nbt(pos, encode_block_nbt(h), notify=False)

    def _insert_item[
        T: WorldTypes
    ](self, mut inv: Inventory, pos: Pos, mut tx: World[T]) -> Bool:
        # Go `insertItem`.
        var dest_pos = pos.side(self.facing)
        var rid = tx.block(dest_pos)
        var br = tx.block_registry()
        var kind = br[].kind(rid)
        if case .Some(done) = T.Blocks.hopper_insert(
            kind, inv, self.facing, dest_pos, tx
        ):
            return done
        if T.Blocks.inventory_size(kind, br[].state_hash(rid)) == 0:
            return False
        var at = container_positions(dest_pos, tx)
        var found = read_container(at, tx)
        if not found:
            return False
        var dest = found.value().copy()
        for slot in range(inv.size()):
            var source: Stack
            try:
                source = inv.item(slot)
            except:
                return False
            if source.empty():
                continue
            if dest.add_item(source.grow(-source.count() + 1)) < 1:
                return False
            try:
                inv.set_item(slot, source.grow(-1))
            except:
                return False
            write_container(at, dest, tx)
            if case .Some(other) = tx.block_as[Hopper](dest_pos):
                var o = other.copy()
                o.transfer_cooldown = 8
                tx.set_block(dest_pos, o)
            return True
        return False

    def _extract_item[
        T: WorldTypes
    ](self, mut inv: Inventory, pos: Pos, mut tx: World[T]) -> Bool:
        # Go `extractItem`.
        var origin_pos = pos.side(Face.UP)
        var rid = tx.block(origin_pos)
        var br = tx.block_registry()
        var kind = br[].kind(rid)
        if case .Some(done) = T.Blocks.hopper_extract(
            kind, inv, origin_pos, tx
        ):
            return done
        if T.Blocks.inventory_size(kind, br[].state_hash(rid)) == 0:
            return False
        var at = container_positions(origin_pos, tx)
        var found = read_container(at, tx)
        if not found:
            return False
        var origin = found.value().copy()
        for slot in range(origin.size()):
            var stack: Stack
            try:
                stack = origin.item(slot)
            except:
                return False
            if stack.empty():
                continue
            if inv.add_item(stack.grow(-stack.count() + 1)) < 1:
                continue
            try:
                origin.set_item(slot, stack.grow(-1))
            except:
                return False
            write_container(at, origin, tx)
            if case .Some(other) = tx.block_as[Hopper](origin_pos):
                var o = other.copy()
                o.transfer_cooldown = 8
                tx.set_block(origin_pos, o)
            return True
        return False

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
