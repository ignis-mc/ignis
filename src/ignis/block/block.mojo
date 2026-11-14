"""Shared block helpers, ported from parts of Dragonfly
`server/block/block.go`.

The embedded helper structs of that file (`solid`, `transparent`,
`replaceable`, the instrument helpers) become methods on each block; see
`docs/architecture.md`.
"""

from minecraft.nbt.tree import Tree
from minecraft.protocol.uuid import UUID

from ..item.inventory.inventory import Inventory
from ..item.stack import Stack
from ..mgl64 import Vec3
from ..world.block import Block
from ..world.block_source import BlockSource
from ..world.world import World, WorldTypes
from .cube.direction import Direction
from .cube.face import Face
from .cube.pos import Pos, pos_from_vec3
from .cube.rotation import Rotation
from ..entity.falling_block import FallingBlock
from ..world.entity import EntityHandle, EntitySpawnOpts
from .hash import AnyBlock, HASH_BAMBOO_MOSAIC, HASH_PLANKS, HASH_WOOL
from ..world.sound.instrument import Instrument

comptime UNKNOWN_DIRECTION = Direction(4)
"""A direction past the four real ones, for blocks that may face none (Go
`unknownDirection`)."""
comptime UNKNOWN_FACE = Face(6)
"""A face past the six real ones (Go `unknownFace`)."""


trait Replaceable:
    """A block that another block may replace when placed (Go
    `Replaceable`)."""

    def replaceable_by(self, b: AnyBlock) -> Bool:
        """Reports whether `b` may replace this block (Go `ReplaceableBy`)."""
        ...


struct User(Copyable):
    """Who uses an item on a block: the parts of Go's `item.User` that
    placement reads. A bare `Rotation` converts to a user at the origin."""

    var rot: Rotation
    """Go `Rotation()`."""
    var pos: Vec3
    """Go `Position()`, the feet."""
    var eye_height: Float64
    """Go `EyeHeight()`."""
    var held: Stack
    """The item being used (Go `HeldItems()`), which carries the NBT of a
    block item such as a shulker box's contents."""

    @implicit
    def __init__(out self, rot: Rotation):
        """Creates a user at the origin with no eye height."""
        self.rot = rot
        self.pos = Vec3()
        self.eye_height = 0
        self.held = Stack()

    def __init__(
        out self,
        rot: Rotation,
        pos: Vec3,
        eye_height: Float64,
        held: Stack = Stack(),
    ):
        """Creates a user."""
        self.rot = rot
        self.pos = pos
        self.eye_height = eye_height
        self.held = held.copy()

    def direction(self) -> Direction:
        """Returns the horizontal direction the user looks in."""
        return self.rot.direction()


def calculate_face(user: User, place_pos: Pos) -> Face:
    """Returns the face a block placed at `place_pos` turns to: up or down
    when the user stands close above or below, else towards the user (Go
    `calculateFace`)."""
    var pos = pos_from_vec3(user.pos)
    if abs(pos.x() - place_pos.x()) < 2 and abs(pos.z() - place_pos.z()) < 2:
        var y = user.pos.y() + user.eye_height
        if y - Float64(place_pos.y()) > 2.0:
            return Face.UP
        elif Float64(place_pos.y()) - y > 0.0:
            return Face.DOWN
    return user.direction().opposite().face()


struct Placement(Copyable):
    """A block a `UsableOnBlock` block places (one call of Go's `place`)."""

    var pos: Pos
    """Where."""
    var block: AnyBlock
    """The block."""
    var ignore_bbox: Bool
    """Place even if an entity is in the way (Go `UseContext.IgnoreBBox`,
    set by doors)."""
    var nbt: Optional[Tree]
    """The block entity NBT the block is placed with, if any."""
    var update: Bool
    """Set the block without the placement checks once the other blocks
    were placed (Go's `tx.SetBlock` after `place`, as chests update the
    chest they pair with)."""
    var contents: Bool
    """The `Items` of `nbt` fill the new block's inventory (a shulker box
    placed from an item that holds items)."""

    def __init__(
        out self,
        pos: Pos,
        block: AnyBlock,
        ignore_bbox: Bool = False,
        *,
        var nbt: Optional[Tree] = None,
        update: Bool = False,
        contents: Bool = False,
    ):
        """Creates a placement."""
        self.pos = pos
        self.block = block
        self.ignore_bbox = ignore_bbox
        self.nbt = nbt^
        self.update = update
        self.contents = contents


trait UsableOnBlock(Block):
    """A block item that decides itself how it is placed (Go
    `item.UsableOnBlock` implemented by blocks)."""

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
        """Returns the blocks to place when the item is used on the face of
        the block at `pos`, clicked at `click` by a user looking at
        `user`; empty if it cannot be placed (Go `UseOnBlock` up to its
        `place` calls)."""
        ...


struct UseContext(Copyable):
    """What activating a block knows about its user and asks of it: Go's
    `item.UseContext` plus the `item.User` parts blocks use, which the
    world cannot reach here (`ContainerOpener`, `Saturate`, `Messaget`,
    jukebox popups). The caller applies the results after `activate`."""

    var user: UUID
    """The user (Go `u.UUID()`, for `SetPlayerSpawn`)."""
    var user_pos: Vec3
    """The user's position (Go `u.Position()`)."""
    var user_rot: Rotation
    """The user's rotation (Go `u.Rotation()`)."""
    var held: Stack
    """The main hand item (Go `u.HeldItems()`)."""
    var sneaking: Bool
    """Go `Sneaking()`."""
    var creative: Bool
    """The user's game mode has a creative inventory."""
    var damage: Int
    """Durability to take from the held item (Go `Damage`)."""
    var count_sub: Int
    """Items to take from the held stack (Go `CountSub`)."""
    var new_item: Stack
    """An item to give the user (Go `NewItem`)."""
    var new_item_survival_only: Bool
    """Give `new_item` only outside creative (Go `NewItemSurvivalOnly`)."""
    var open_container: Bool
    """Open the block's window (Go `ContainerOpener.OpenBlockContainer`)."""
    var food: Int
    """Food to restore (Go `Saturate`)."""
    var saturation: Float64
    """Saturation to restore (Go `Saturate`)."""
    var messages: List[String]
    """Translation keys to show the user (Go `Messaget`)."""
    var popup: String
    """A jukebox popup text (Go `SendJukeboxPopup`)."""

    def __init__(out self):
        """Creates a context for an anonymous user with an empty hand."""
        self.user = UUID()
        self.user_pos = Vec3()
        self.user_rot = Rotation()
        self.held = Stack()
        self.sneaking = False
        self.creative = False
        self.damage = 0
        self.count_sub = 0
        self.new_item = Stack()
        self.new_item_survival_only = False
        self.open_container = False
        self.food = 0
        self.saturation = 0
        self.messages = List[String]()
        self.popup = String()

    def subtract_from_count(mut self, n: Int):
        """Takes `n` more items from the held stack (Go
        `SubtractFromCount`)."""
        self.count_sub += n

    def damage_item(mut self, d: Int):
        """Takes `d` more durability from the held item (Go
        `DamageItem`)."""
        self.damage += d


trait Activatable(Block):
    """A block that does something when used (Go `block.Activatable`)."""

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Activates the block at `pos`, clicked on `face`; True if it was
        used, which stops the held item from being used (Go `Activate`).
        `self` carries the block entity's NBT."""
        ...


trait Openable(Block):
    """A block whose window viewers open, with an animation when the first
    opens and the last closes (Go's `open` and `close` in the
    `AddViewer` and `RemoveViewer` of chests, barrels, ender chests and
    shulker boxes)."""

    def opened[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """The first viewer opened the block (Go `open`)."""
        ...

    def closed[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """The last viewer closed the block (Go `close`)."""
        ...


trait BreakHandler(Block):
    """A block that does something as it is broken (Go
    `BreakInfo.withBreakHandler`), such as spilling its contents."""

    def on_break[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], harvest: Bool):
        """Runs before the block is removed; `harvest` is False when the
        breaker gets no drops (creative). `self` carries its NBT."""
        ...


trait HopperInsertable(Block):
    """A block a hopper feeds in its own way (Go `HopperInsertable`), such
    as a furnace taking fuel from the side."""

    def insert_item[
        T: WorldTypes
    ](
        self, mut hopper: Inventory, facing: Face, pos: Pos, mut tx: World[T]
    ) -> Bool:
        """Moves one item from a hopper facing `facing` into the block at
        `pos`; True if one moved (Go `InsertItem`)."""
        ...


trait HopperExtractable(Block):
    """A block a hopper below takes from in its own way (Go
    `HopperExtractable`)."""

    def extract_item[
        T: WorldTypes
    ](self, mut hopper: Inventory, pos: Pos, mut tx: World[T]) -> Bool:
        """Moves one item from the block at `pos` into a hopper; True if one
        moved (Go `ExtractItem`)."""
        ...


trait BeaconSource(Block):
    """A block a beacon's pyramid may be built from (Go `BeaconSource`)."""

    def powers_beacon(self) -> Bool:
        """Reports whether the block powers a beacon (Go `PowersBeacon`)."""
        ...


trait StateDeriver(Block):
    """A block whose state depends on its neighbours (Go
    `world.StateDeriver`); placing it derives the state first."""

    def derive_state[S: BlockSource](self, pos: Pos, src: S) -> Self:
        """Returns the block as it should be at `pos` (Go `DeriveState`)."""
        ...


trait Instrumented:
    """A block that picks the instrument of a note block above it (the
    `Instrument()` interface Go's `Note.instrument` asserts)."""

    def instrument(self) -> Instrument:
        """Returns the instrument (Go `Instrument`)."""
        ...


def slab_instrument(b: AnyBlock) -> Instrument:
    """Returns the instrument of slabs and stairs made of `b` (Go
    `Slab.Instrument` and `Stairs.Instrument`)."""
    if b.kind == HASH_PLANKS or b.kind == HASH_BAMBOO_MOSAIC:
        return Instrument.BASS
    if b.kind == HASH_WOOL:
        return Instrument.GUITAR
    return Instrument.BASS_DRUM


def replaceable_with[
    T: WorldTypes
](mut tx: World[T], pos: Pos, with_: AnyBlock) -> Bool:
    """Reports whether the block at `pos` may be replaced by `with_` (Go
    `replaceableWith`)."""
    if pos.out_of_bounds(tx.range()):
        return False
    var br = tx.block_registry()
    var rid = tx.block(pos)
    var kind = br[].kind(rid)
    var hash = br[].state_hash(rid)
    if not T.Blocks.replaceable_by(kind, hash, with_):
        return False
    if AnyBlock(kind, hash) == with_:
        return False
    if case .Some(l) = tx.liquid(pos):
        return T.Blocks.replaceable_by(br[].kind(l), br[].state_hash(l), with_)
    return True


def first_replaceable[
    T: WorldTypes
](mut tx: World[T], pos: Pos, face: Face, with_: AnyBlock) -> Optional[
    Tuple[Pos, Face]
]:
    """Returns where `with_` goes when used on a face of the block at `pos`:
    into the block if it is replaceable (then on its top face), else on the
    clicked side (Go `firstReplaceable`); None if neither is free."""
    if replaceable_with(tx, pos, with_):
        return (pos, Face.UP)
    var side = pos.side(face)
    if replaceable_with(tx, side, with_):
        return (side, face)
    return None


def horizontal_direction(d: Direction) -> Direction:
    """Converts a direction to the legacy horizontal direction some block
    properties use (Go `horizontalDirection`)."""
    if d == Direction.SOUTH:
        return Direction.NORTH
    if d == Direction.WEST:
        return Direction.SOUTH
    if d == Direction.NORTH:
        return Direction.WEST
    return Direction.EAST


@fieldwise_init
struct FlammabilityInfo(ImplicitlyCopyable):
    """How a block behaves with fire (Go `FlammabilityInfo`)."""

    var encouragement: Int
    """The chance the block catches fire when fire spreads."""
    var flammability: Int
    """The chance the block burns away when fire next to it ticks."""
    var lava_flammable: Bool
    """Whether lava can set it on fire."""


trait Flammable:
    """A block that can catch fire (Go `Flammable`)."""

    def flammability_info(self) -> FlammabilityInfo:
        """Returns how the block behaves with fire (Go
        `FlammabilityInfo`)."""
        ...


trait Solidifiable:
    """A falling block that can stop falling next to some blocks, such as
    concrete powder next to water (Go `entity.Solidifiable`)."""

    def solidifies[T: WorldTypes](self, pos: Pos, mut tx: World[T]) -> Bool:
        """Reports whether the falling block stops at `pos` (Go
        `Solidifies`)."""
        ...


def gravity_fall[B: Block, T: WorldTypes](b: B, pos: Pos, mut tx: World[T]):
    """Turns a block with nothing under it into a falling block entity (Go
    `gravityAffected.fall`). Worlds whose entity set lacks falling blocks
    leave it in place."""
    if not replaceable_with(tx, pos.side(Face.DOWN), AnyBlock(b)):
        return
    var br = tx.block_registry()
    var rid = br[].block_runtime_id(b)
    var state = T.Entities.try_wrap(
        FallingBlock(AnyBlock(b), br[].state(rid).copy())
    )
    if not state:
        return
    tx.set_block_runtime_id(pos, br[].air_runtime_id())
    var opts = EntitySpawnOpts()
    opts.position = pos.vec3_centre()
    _ = tx.add_entity(EntityHandle[T.Entities](opts, state.take()))


def face_solid_at[
    T: WorldTypes
](mut tx: World[T], pos: Pos, face: Face) -> Bool:
    """Reports whether a face of the block at `pos` is solid (Go
    `tx.Block(pos).Model().FaceSolid(pos, face, tx)`)."""
    var rid = tx.block(pos)
    var br = tx.block_registry()
    return T.Blocks.face_solid(
        br[].kind(rid), br[].state_hash(rid), pos, face, tx.source()
    )


def is_air[T: WorldTypes](mut tx: World[T], pos: Pos) -> Bool:
    """Reports whether the block at `pos` is air (Go `tx.Block(pos).(Air)`)."""
    return tx.block(pos) == tx.block_registry()[].air_runtime_id()


def light_diffuser_at[
    T: WorldTypes
](mut tx: World[T], pos: Pos) -> Optional[UInt8]:
    """Returns the light diffusion level of the block at `pos` if it is a
    `LightDiffuser` (Go `tx.Block(pos).(LightDiffuser)`)."""
    var rid = tx.block(pos)
    var br = tx.block_registry()
    var f = br[].filtering_block(rid)
    if T.Blocks.is_light_diffuser(br[].kind(rid), br[].state_hash(rid)):
        return f
    return None
