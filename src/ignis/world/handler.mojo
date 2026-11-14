"""World event handlers, ported from Dragonfly `server/world/handler.go`.

A world holds one `Handler` (`WorldTypes.Handler`) and calls it for world
events. Every method has an empty default body, which replaces embedding
Go's `NopHandler`. Handler methods receive the world as `tx`; the world
takes its handler out while calling it, so a handler can use the world
freely but cannot reach itself through it.

Only the events whose types are ported exist so far: entity spawn and
despawn and closing. The liquid, sound, fire, crop, leaves, portal,
explosion and redstone events come with those systems.
"""

from .entity import EntityHandle
from .world import World, WorldTypes


trait Handler(Deinitable, Movable):
    """Handles events of a world (Go `Handler`)."""

    def handle_entity_spawn[
        T: WorldTypes
    ](mut self, mut tx: World[T], e: EntityHandle[T.Entities]):
        """Handles an entity being added to the world (Go
        `HandleEntitySpawn`)."""
        pass

    def handle_entity_despawn[
        T: WorldTypes
    ](mut self, mut tx: World[T], e: EntityHandle[T.Entities]):
        """Handles an entity being removed from the world (Go
        `HandleEntityDespawn`)."""
        pass

    def handle_close[T: WorldTypes](mut self, mut tx: World[T]):
        """Handles the world closing, before chunks are saved (Go
        `HandleClose`)."""
        pass


struct NopHandler(Defaultable, Handler):
    """A handler that ignores every event (Go `NopHandler`)."""

    def __init__(out self):
        """Creates the handler."""
        pass
