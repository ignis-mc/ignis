"""`Fire`, ported from Dragonfly `server/block/fire.go`.

Go's `replaceable` helper comes with `world.Tx`.

TODO(world-runtime): infinitelyBurning, burn, tick, ScheduledTick,
RandomTick, NeighbourUpdateTick, EntityInside, FireDamageSource, Start and
the fire spread helpers.
"""

from .block import Replaceable, face_solid_at
from .hash import AnyBlock, HASH_FIRE
from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .connections import FireConnections, all_fire_connections
from .fire_type import FireType
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable
from ..world.world import World, WorldTypes
from .cube.face import Face
from .cube.pos import Pos
from .fern import Fern
from .short_grass import ShortGrass


struct Fire(
    Block,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    LightEmitter,
    LiquidRemovable,
    ModelledBlock,
    Replaceable,
):
    """A non-solid block that can spread to nearby flammable blocks."""

    comptime BASE_HASH: UInt64 = HASH_FIRE
    """Go `hashFire`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var type: FireType
    """The type of fire."""
    var age: Int
    """How long the fire has burned, 0 to 15."""
    var connections: FireConnections
    """The sides normal fire attaches to."""

    def __init__(
        out self,
        *,
        type: FireType = FireType.NORMAL,
        age: Int = 0,
        connections: FireConnections = FireConnections(),
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type
        self.age = age
        self.connections = connections

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.type == FireType.SOUL:
            return BlockState(
                "minecraft:soul_fire",
                Properties().with_int("age", Int32(self.age)),
            )
        return BlockState(
            "minecraft:fire",
            self.connections.properties(Properties()).with_int(
                "age", Int32(self.age)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.type.uint8())
            | UInt64(self.age) << 1
            | UInt64(self.connections.uint8()) << 9
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Fire(
            type=FireType(Int(hash & 0x1)),
            age=Int((hash >> 1) & 0xFF),
            connections=FireConnections(bits=Int((hash >> 9) & 0x1F)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for i in range(16):
            for c in all_fire_connections():
                out.append(Fire(age=i, type=FireType.NORMAL, connections=c))
            out.append(Fire(age=i, type=FireType.SOUL))
        return out^

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return self.type.light_level()

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def replaceable_by(self, b: AnyBlock) -> Bool:
        """Any block replaces it (Go's embedded `replaceable`)."""
        return True

    def has_liquid_drops(self) -> Bool:
        """Returns False (Go `HasLiquidDrops`)."""
        return False


def flammable_block[T: WorldTypes](mut tx: World[T], pos: Pos) -> Bool:
    """Reports whether the block at `pos` can catch fire (Go
    `flammableBlock`)."""
    var rid = tx.block(pos)
    var br = tx.block_registry()
    if case .Some(f) = T.Blocks.flammability(
        br[].kind(rid), br[].state_hash(rid)
    ):
        return f.encouragement > 0
    return False


def neighbours_flammable[T: WorldTypes](mut tx: World[T], pos: Pos) -> Bool:
    """Reports whether a block next to `pos` can catch fire (Go
    `neighboursFlammable`)."""
    for i in range(6):
        if flammable_block(tx, pos.side(Face(i))):
            return True
    return False


def fire_connections[
    T: WorldTypes
](f: Fire, pos: Pos, mut tx: World[T]) -> FireConnections:
    """Returns the sides fire at `pos` attaches to (Go `connections`)."""
    if f.type == FireType.SOUL:
        return FireConnections()
    # Fire on a full top face or on a flammable block burns on the ground.
    var below = pos.side(Face.DOWN)
    if flammable_block(tx, below) or face_solid_at(tx, below, Face.UP):
        return FireConnections()
    return FireConnections(
        flammable_block(tx, pos.side(Face.NORTH)),
        flammable_block(tx, pos.side(Face.EAST)),
        flammable_block(tx, pos.side(Face.SOUTH)),
        flammable_block(tx, pos.side(Face.WEST)),
        flammable_block(tx, pos.side(Face.UP)),
    )


def start_fire[T: WorldTypes](mut tx: World[T], pos: Pos):
    """Sets fire to air, short grass or a fern at `pos` if it has a solid
    block under it or something flammable next to it (Go `Fire.Start`;
    nether portals are not ported). Go asks the block below about its face
    at `pos`; this asks it about its own position."""
    var b = tx.block(pos)
    var br = tx.block_registry()
    if not (
        b == br[].air_runtime_id()
        or br[].is_block[ShortGrass](b)
        or br[].is_block[Fern](b)
    ):
        return
    if face_solid_at(tx, pos.side(Face.DOWN), Face.UP) or neighbours_flammable(
        tx, pos
    ):
        var f = Fire()
        f.connections = fire_connections(f, pos, tx)
        tx.set_block(pos, f)
        tx.schedule_block_update(pos, f, (30 + tx.global_rand().int_n(10)) * 50)
