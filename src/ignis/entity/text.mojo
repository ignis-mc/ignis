"""Text entities, ported from Dragonfly `server/entity/text.go`, with the
parts of `ent.go` (`Ent.Tick`) and `stationary.go` (`StationaryBehaviour`)
they use.

Not ported yet: spawn sounds and the extra tick function of
`StationaryBehaviourConfig`, the fire state update shown to viewers, and
portal travel.
"""

from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..mgl64 import Vec3
from ..world.entity import (
    EntityData,
    EntityHandle,
    EntityMovement,
    EntitySpawnOpts,
    EntityTypes,
    NetworkEncodedEntity,
    TickerEntity,
)
from ..world.world import World, WorldTypes


@fieldwise_init
struct Text(Copyable, NetworkEncodedEntity, TickerEntity):
    """An entity that only displays text: its name tag (Go `TextType` with
    a `StationaryBehaviour`)."""

    comptime IDENTIFIER: StaticString = "dragonfly:text"
    """Go `textType.EncodeEntity`."""
    comptime NETWORK_IDENTIFIER: StaticString = "minecraft:falling_block"
    """Go `textType.NetworkEncodeEntity`: clients see a falling block."""

    var existence_duration_ms: Int
    """How long the entity lasts; 0 is forever (Go
    `StationaryBehaviourConfig.ExistenceDuration`)."""
    var close: Bool
    """Set when the existence duration has passed; the entity closes on
    its next tick (Go `StationaryBehaviour.close`)."""

    def __init__(out self):
        """Creates a text entity that lasts forever (Go `textConf`)."""
        self.existence_duration_ms = 0
        self.close = False

    def bbox(self, data: EntityData) -> BBox:
        """Returns the bounding box (Go `textType.BBox`).

        Args:
            data: The entity's data.

        Returns:
            An empty box.
        """
        return BBox()

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes nothing: text entities have no fields of their own (Go
        `textType.EncodeNBT`).

        Args:
            data: The entity's data.
            tree: The tree being written.
            tag: The entity's compound.

        Raises:
            Never; the signature follows the trait.
        """
        pass

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Creates the state of a loaded text entity (Go
        `textType.DecodeNBT`).

        Args:
            tree: The tree read.
            tag: The entity's compound.
            data: The entity's data.

        Returns:
            A text entity that lasts forever.

        Raises:
            Never; the signature follows the trait.
        """
        return Self()

    def tick[
        T: WorldTypes
    ](
        mut self,
        id: UUID,
        mut data: EntityData,
        mut tx: World[T],
        current: Int64,
    ) -> Optional[EntityMovement]:
        """Ticks the entity (Go `Ent.Tick` with `StationaryBehaviour.Tick`):
        it closes below the world or once its time is up, never moves, and
        ages.

        Parameters:
            T: The world's types.

        Args:
            id: The entity's UUID.
            data: The entity's data.
            tx: The world.
            current: The current tick.

        Returns:
            None: stationary entities never move.
        """
        if data.pos.y() < Float64(tx.range().min()) and current % 10 == 0:
            _ = tx.remove_entity(id)
            return None
        data.fire_duration_ms = max(data.fire_duration_ms - 50, 0)
        if self.close:
            _ = tx.remove_entity(id)
            return None
        if (
            self.existence_duration_ms > 0
            and data.age_ms > self.existence_duration_ms
        ):
            self.close = True
        data.age_ms += 50
        return None


def new_text[E: EntityTypes](text: String, pos: Vec3) -> EntityHandle[E]:
    """Creates a text entity (Go `NewText`). The entity set `E` must
    contain `Text`.

    Parameters:
        E: The world's entity set.

    Args:
        text: The text, shown as the name tag.
        pos: The position.

    Returns:
        The entity, to add with `World.add_entity`.
    """
    var opts = EntitySpawnOpts()
    opts.position = pos
    opts.name_tag = text
    return EntityHandle[E](opts, E.wrap(Text()))
