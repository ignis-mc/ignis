"""Viewers, ported from Dragonfly `server/world/viewer.go`.

A viewer sees the parts of a world its `Loader` has loaded: chunks, block
changes, entities, time and weather. Sessions implement `Viewer` to turn
these calls into packets. The world owns each loader's viewer (`World.viewer`
gives it back to drain), so a session keeps whatever it must share with its
viewer, such as a packet queue, behind an `ArcPointer`.

Every method has an empty default body, which replaces Go's `NopViewer`
embedding: implement only what you need. Entity methods are generic over the
world's entity set. Blocks are runtime IDs, as everywhere in Ignis.

Containers add Go's `ContainerViewer.ViewSlotChange`, and
`view_block_entity` stands for the `BlockActorData` Go's session sends from
`ViewBlockUpdate`. Block entities of whole chunks reach sessions with the
sub-chunks they request (`World.network_block_entities`).

Not ported yet (they need unported types): `ViewEntityGameMode`,
`ViewEntityDisplacement`, `ViewBrewingUpdate`, `ViewEntityAction`,
`ViewEntityState`, `ViewEntityAnimation`, `ViewEmote`, `ViewSkin` and
`ViewEntityWake`.
"""

from minecraft.nbt.tree import Tree

from ..block.cube.pos import Pos
from ..item.stack import Stack
from ..block.cube.rotation import Rotation
from ..mgl64 import Vec3
from .chunk.chunk import Chunk
from .dimension import Dimension
from .entity import EntityHandle, EntityTypes
from .particle import Particle
from .sound import Sound
from .position import ChunkPos


comptime BLOCK_ACTION_OPEN = 0
"""Go `block.OpenAction`: a chest or barrel opens."""
comptime BLOCK_ACTION_CLOSE = 1
"""Go `block.CloseAction`: a chest or barrel closes."""


trait Viewer(Deinitable, Movable):
    """Something that views a part of a world (Go `Viewer`)."""

    def view_entity[E: EntityTypes](mut self, e: EntityHandle[E]):
        """Starts viewing an entity that came into range (Go `ViewEntity`)."""
        pass

    def hide_entity[E: EntityTypes](mut self, e: EntityHandle[E]):
        """Stops viewing an entity that left range or the world (Go
        `HideEntity`)."""
        pass

    def view_entity_movement[
        E: EntityTypes
    ](mut self, e: EntityHandle[E], pos: Vec3, rot: Rotation, on_ground: Bool,):
        """Views an entity moving to a new position and rotation (Go
        `ViewEntityMovement`)."""
        pass

    def view_entity_velocity[
        E: EntityTypes
    ](mut self, e: EntityHandle[E], vel: Vec3):
        """Views the velocity of an entity (Go `ViewEntityVelocity`)."""
        pass

    def view_entity_teleport[
        E: EntityTypes
    ](mut self, e: EntityHandle[E], pos: Vec3):
        """Views an entity teleporting (Go `ViewEntityTeleport`)."""
        pass

    def view_entity_items[E: EntityTypes](mut self, e: EntityHandle[E]):
        """Views the items an entity holds (Go `ViewEntityItems`)."""
        pass

    def view_entity_armour[E: EntityTypes](mut self, e: EntityHandle[E]):
        """Views the armour an entity wears (Go `ViewEntityArmour`)."""
        pass

    def view_chunk(mut self, pos: ChunkPos, dim: Dimension, c: Chunk):
        """Views a chunk the loader loaded (Go `ViewChunk`)."""
        pass

    def view_time(mut self, t: Int):
        """Views the time of day (Go `ViewTime`); called when it changes and
        every second."""
        pass

    def view_time_cycle(mut self, do_day_light_cycle: Bool):
        """Views whether time advances (Go `ViewTimeCycle`)."""
        pass

    def view_block_update(mut self, pos: Pos, rid: UInt32, layer: Int):
        """Views a block being set (Go `ViewBlockUpdate`)."""
        pass

    def view_block_entity(mut self, pos: Pos, nbt: Tree):
        """Views the network NBT of a block entity, `x`, `y` and `z`
        included (Go's `BlockActorData` in `ViewBlockUpdate`)."""
        pass

    def view_block_action(mut self, pos: Pos, action: Int):
        """Views a `BLOCK_ACTION_*` at a block (Go `ViewBlockAction`)."""
        pass

    def view_slot_change(mut self, slot: Int, it: Stack):
        """Views a slot of the container the viewer opened changing (Go
        `ContainerViewer.ViewSlotChange`)."""
        pass

    def view_furnace_update(
        mut self,
        prev_cook_ms: Int,
        cook_ms: Int,
        prev_remaining_ms: Int,
        remaining_ms: Int,
        prev_max_ms: Int,
        max_ms: Int,
    ):
        """Views the progress of the smelter the viewer opened (Go
        `ViewFurnaceUpdate`)."""
        pass

    def view_container_removed(mut self):
        """The container the viewer opened is gone; its window closes."""
        pass

    def view_sound[S: Sound](mut self, pos: Vec3, s: S):
        """Plays a sound at a position (Go `ViewSound`)."""
        pass

    def view_particle[P: Particle](mut self, pos: Vec3, p: P):
        """Shows a particle at a position (Go `ViewParticle`)."""
        pass

    def view_world_spawn(mut self, pos: Pos):
        """Views the world's spawn position (Go `ViewWorldSpawn`)."""
        pass

    def view_weather(mut self, raining: Bool, thunder: Bool):
        """Views the weather (Go `ViewWeather`)."""
        pass


struct NopViewer(Defaultable, Viewer):
    """A viewer that ignores everything (Go `NopViewer`)."""

    def __init__(out self):
        """Creates the viewer."""
        pass
