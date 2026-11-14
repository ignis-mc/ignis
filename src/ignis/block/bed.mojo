"""`Bed`, ported from Dragonfly `server/block/bed.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

`activate` sets the user's spawn with Go's checks and messages but does not
put the user to sleep (sleeping is not ported). Outside the overworld Go
removes the bed and explodes; explosions are not ported, so the bed is only
removed.

TODO(world-runtime): the `Sleeper` entity handle, sleeping, UseOnBlock (the
colour needs placement NBT), EntityLand, bounce, the break handler waking the
sleeper and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_uint8
from ..item.colour import Colour, colours
from ..item.item import MaxCounter
from ..world.block import (
    Block,
    LightDiffuser,
    LiquidDisplacer,
    NBTer,
    NeighbourUpdateTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item, ItemHasher
from .air import Air
from .block import (
    Activatable,
    UseContext,
    face_solid_at,
    horizontal_direction,
    is_air,
    light_diffuser_at,
)
from .model.empty import Empty as EmptyModel
from .model.solid import Solid as SolidModel
from .register import block_model_as
from ..world.dimension import OVERWORLD
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import AnyBlock, HASH_BED
from .model.bed import Bed as BedModel
from .liquid import source_water_can_displace
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face


struct Bed(
    Activatable,
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ItemHasher,
    LightDiffuser,
    LiquidDisplacer,
    MaxCounter,
    ModelledBlock,
    NBTer,
    NeighbourUpdateTicker,
):
    """A block that allows players to sleep to set their spawn point and skip the night.
    """

    comptime BASE_HASH: UInt64 = HASH_BED
    """Go `hashBed`."""
    comptime ModelType = BedModel
    """The model type (Go `Model`)."""

    var colour: Colour
    """The colour of the bed, kept in NBT."""
    var facing: Direction
    """The direction the head of the bed faces."""
    var head: Bool
    """Whether this is the head of the bed."""
    var occupied: Bool
    """Whether someone sleeps in the bed."""

    def __init__(
        out self,
        *,
        colour: Colour = Colour.WHITE,
        facing: Direction = Direction.NORTH,
        head: Bool = False,
        occupied: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.colour = colour
        self.facing = facing
        self.head = head
        self.occupied = occupied

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash() and self.colour == other.colour

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:bed",
            Properties()
            .with_int(
                "direction", Int32(Int(horizontal_direction(self.facing)))
            )
            .with_byte("occupied_bit", UInt8(self.occupied))
            .with_byte("head_piece_bit", UInt8(self.head)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.head else UInt64(0)) << 2
            | (UInt64(1) if self.occupied else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Bed(
            facing=Direction(Int(hash & 0x3)),
            head=(hash >> 2) & 0x1 != 0,
            occupied=(hash >> 3) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for d in directions():
            for head in [False, True]:
                for occupied in [False, True]:
                    out.append(Bed(facing=d, head=head, occupied=occupied))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.2, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> BedModel:
        """Returns the model of the block (Go `Model`)."""
        return BedModel()

    def max_count(self) -> Int:
        """Returns the maximum stack count (Go `MaxCount`)."""
        return 1

    def item_hash(self) -> UInt64:
        """Returns the item hash: the state hash with the colour, which Go
        keeps in the block entity, in bits 8 to 11."""
        return self.hash() | UInt64(self.colour.uint8()) << 8

    @staticmethod
    def from_item_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its `item_hash`."""
        var b = Self.from_hash(hash & 0xFF)
        b.colour = Colour(Int((hash >> 8) & 0xF))
        return b^

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:bed", Int16(self.colour.uint8()))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for c in colours():
            out.append(Self(colour=c))
        return out^

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "Bed")
        _ = tag.put_byte(root, "color", self.colour.uint8())

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var c = Int(get_uint8(tag, root, "color"))
        if c > 15:
            # Go indexes Colours() and panics.
            raise Error(t"bed: invalid colour {c}")
        var b = self.copy()
        b.colour = Colour(c)
        return b^

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Sets the user's spawn at the bed (Go `Activate` up to `Sleep`)."""
        if tx.dimension() != OVERWORLD:
            # Go also explodes here (ExplosionConfig.Explode).
            tx.set_block(pos, Air())
            return True
        var side = self.side(pos, tx)
        if not side:
            return False
        var side_pos = side.value()[1]
        var user_pos = ctx.user_pos
        if (
            side_pos.vec3_middle().sub(user_pos).len() > 2
            and pos.vec3_middle().sub(user_pos).len() > 2
        ):
            ctx.messages.append(MESSAGE_BED_TOO_FAR)
            return True
        var head = self.head_side(pos, tx)
        if not head:
            return False
        var head_side = head.value()[0]
        var head_pos = head.value()[1]
        if not self.safe_spawn(pos, tx):
            ctx.messages.append(MESSAGE_BED_OBSTRUCTED)
            return False
        if tx.liquid(head_pos):
            return False
        if tx.player_spawn(ctx.user) != head_pos:
            tx.set_player_spawn(ctx.user, head_pos)
            ctx.messages.append(MESSAGE_RESPAWN_POINT_SET)
        var time = tx.time() % TIME_FULL
        if not tx.thundering():
            if not tx.raining() and (time <= TIME_SLEEP or time >= TIME_WAKE):
                ctx.messages.append(MESSAGE_NO_SLEEP)
                return True
            if time <= TIME_SLEEP_WITH_RAIN or time >= TIME_WAKE_WITH_RAIN:
                ctx.messages.append(MESSAGE_NO_SLEEP)
                return True
        if head_side.occupied:
            ctx.messages.append(MESSAGE_BED_IS_OCCUPIED)
            return True
        # TODO(world-runtime): s.Sleep(headPos) once players can sleep.
        return True

    def head_side[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T]) -> Optional[Tuple[Bed, Pos]]:
        """Returns the head half of the bed and its position (Go `head`)."""
        var side = self.side(pos, tx)
        if not side:
            return None
        if self.head:
            return (self, pos)
        return side

    def side[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T]) -> Optional[Tuple[Bed, Pos]]:
        """Returns the other half of the bed and its position (Go `side`)."""
        var side_pos = bed_side(pos, self.facing, self.head)
        if case .Some(o) = tx.block_as[Bed](side_pos):
            return (o, side_pos)
        return None

    def safe_spawn[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T]) -> Optional[Pos]:
        """Returns a free position next to the bed to spawn at (Go
        `SafeSpawn`)."""
        var head = self.head_side(pos, tx)
        if not head:
            return None
        var heel_pos = head.value()[1].side(self.facing.opposite().face())
        var br = tx.block_registry()
        for offset in bed_offsets(self.facing):
            var p = heel_pos.add(offset)
            var rid = tx.block(p)
            if block_model_as[SolidModel](
                AnyBlock(br[].kind(rid), br[].state_hash(rid))
            ):
                var d = light_diffuser_at(tx, p)
                if not d or d.value() != 0:
                    continue
            var below = tx.block(p.side(Face.DOWN))
            if block_model_as[EmptyModel](
                AnyBlock(br[].kind(below), br[].state_hash(below))
            ):
                continue
            return p
        return None

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks without its other half (Go `NeighbourUpdateTick`)."""
        var face = self.facing.face()
        if self.head:
            face = face.opposite()
        if not tx.block_as[Bed](pos.side(face)):
            break_block_no_drops(self, pos, tx)


comptime TIME_SLEEP = 12542
"""The time from which players may sleep (Go `world.TimeSleep`)."""
comptime TIME_WAKE = 23459
"""The time players wake up (Go `world.TimeWake`)."""
comptime TIME_SLEEP_WITH_RAIN = 12010
"""The time from which players may sleep when it rains (Go
`world.TimeSleepWithRain`)."""
comptime TIME_WAKE_WITH_RAIN = 23991
"""The time players wake up when it rains (Go `world.TimeWakeWithRain`)."""
comptime TIME_FULL = 24000
"""The length of a day (Go `world.TimeFull`)."""

comptime MESSAGE_BED_TOO_FAR = "§7%tile.bed.tooFar§r"
"""Go `chat.MessageBedTooFar` as `Messaget` sends it."""
comptime MESSAGE_BED_OBSTRUCTED = "§7%tile.bed.obstructed§r"
"""Go `chat.MessageBedObstructed`."""
comptime MESSAGE_RESPAWN_POINT_SET = "§7%tile.bed.respawnSet§r"
"""Go `chat.MessageRespawnPointSet`."""
comptime MESSAGE_NO_SLEEP = "§7%tile.bed.noSleep§r"
"""Go `chat.MessageNoSleep`."""
comptime MESSAGE_BED_IS_OCCUPIED = "§7%tile.bed.occupied§r"
"""Go `chat.MessageBedIsOccupied`."""


def bed_side(pos: Pos, facing: Direction, head: Bool) -> Pos:
    """Returns the position of the other half of a bed (Go `bedSide`)."""
    var face = facing.face()
    if head:
        face = face.opposite()
    return pos.side(face)


def bed_offsets(facing: Direction) -> List[Pos]:
    """Returns the spawn candidates around a bed relative to its heel, in
    Go's order (Go `bedOffsets`)."""
    if facing == Direction.NORTH:
        return [
            Pos(-1, 0, 0),
            Pos(-1, 0, 1),
            Pos(0, 0, 1),
            Pos(1, 0, 1),
            Pos(1, 0, 0),
            Pos(1, 0, -1),
            Pos(1, 0, -2),
            Pos(0, 0, -2),
            Pos(-1, 0, -2),
            Pos(-1, 0, -1),
            Pos(0, 1, -1),
            Pos(0, 1, 0),
        ]
    if facing == Direction.EAST:
        return [
            Pos(0, 0, -1),
            Pos(-1, 0, -1),
            Pos(-1, 0, 0),
            Pos(-1, 0, 1),
            Pos(-1, 0, 1),
            Pos(0, 0, 1),
            Pos(1, 0, 1),
            Pos(2, 0, 1),
            Pos(2, 0, 0),
            Pos(2, 0, -1),
            Pos(1, 0, -1),
            Pos(1, 1, 0),
            Pos(0, 1, 0),
        ]
    if facing == Direction.SOUTH:
        return [
            Pos(1, 0, 0),
            Pos(1, 0, -1),
            Pos(0, 0, -1),
            Pos(-1, 0, -1),
            Pos(-1, 0, 0),
            Pos(-1, 0, 1),
            Pos(-1, 0, 2),
            Pos(0, 0, 2),
            Pos(1, 0, 2),
            Pos(1, 0, 1),
            Pos(0, 1, 1),
            Pos(0, 1, 0),
        ]
    return [
        Pos(0, 0, 1),
        Pos(1, 0, 1),
        Pos(1, 0, 0),
        Pos(1, 0, -1),
        Pos(1, 0, -1),
        Pos(0, 0, -1),
        Pos(-1, 0, -1),
        Pos(-2, 0, -1),
        Pos(-2, 0, 0),
        Pos(-2, 0, 1),
        Pos(-1, 0, 1),
        Pos(-1, 1, 0),
        Pos(0, 1, 0),
    ]
