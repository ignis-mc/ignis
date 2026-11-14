"""`DragonEgg`, ported from Dragonfly `server/block/dragon_egg.go`.

TODO(world-runtime): Punch, the falling behaviour of `gravityAffected` and the
drops.
"""

from ..world.particle.block import DragonEggTeleport
from .air import Air
from .block import Activatable, UseContext, is_air


from ..world.block import (
    Block,
    LightDiffuser,
    LightEmitter,
    LiquidDisplacer,
    NeighbourUpdateTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .hash import AnyBlock, HASH_DRAGON_EGG
from .model.solid import Solid as SolidModel
from .liquid import source_water_can_displace
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import gravity_fall


struct DragonEgg(
    Activatable,
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    LiquidDisplacer,
    ModelledBlock,
    NeighbourUpdateTicker,
):
    """A decorative block or a "trophy item", and the rarest item in the game.
    """

    comptime BASE_HASH: UInt64 = HASH_DRAGON_EGG
    """Go `hashDragonEgg`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `DragonEgg{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Teleports the egg (Go `Activate`)."""
        self.teleport(pos, tx)
        return True

    def teleport[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Moves the egg to a random free spot nearby (Go `teleport`)."""
        var r = tx.range()
        for _ in range(1000):
            var x = tx.global_rand().int_n(31) - 15
            var y = max(
                r.min() - pos.y(),
                min(r.max() - pos.y(), tx.global_rand().int_n(15) - 7),
            )
            var z = tx.global_rand().int_n(31) - 15
            var new_pos = pos.add(Pos(x, y, z))
            if is_air(tx, new_pos):
                tx.set_block(new_pos, self)
                tx.set_block(pos, Air())
                tx.add_particle(
                    pos.vec3(), DragonEggTeleport(diff=pos.sub(new_pos))
                )
                return

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:dragon_egg")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return DragonEgg()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [DragonEgg()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            3, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(9)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 1

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:dragon_egg", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Falls when nothing holds it up (Go `NeighbourUpdateTick`)."""
        gravity_fall(self, pos, tx)
