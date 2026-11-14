"""`Fire`, ported from Dragonfly `server/block/fire.go`.

Go's `replaceable` helper comes with `world.Tx`.

TODO(world-runtime): infinitelyBurning, burn, tick, ScheduledTick,
RandomTick, NeighbourUpdateTick, EntityInside, FireDamageSource, Start and
the fire spread helpers.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .connections import FireConnections, all_fire_connections
from .fire_type import FireType
from .hash import HASH_FIRE
from .model.empty import Empty as EmptyModel


struct Fire(
    Block,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
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
