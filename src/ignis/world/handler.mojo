"""World event handlers, ported from Dragonfly `server/world/handler.go`.

A world holds one `Handler` (`WorldTypes.Handler`) and calls it for world
events. Every method has an empty default body, which replaces embedding
Go's `NopHandler`. Handler methods receive the world as `tx`; the world
takes its handler out while calling it, so a handler can use the world
freely but cannot reach itself through it.

Blocks are passed as `AnyBlock`s (Go passes `world.Block` values) and
entities as UUIDs. The sound, portal and redstone events come with those
systems.
"""

from ..block.cube.pos import Pos
from ..block.hash import AnyBlock
from minecraft.protocol.uuid import UUID

from ..mgl64 import Vec3
from .entity import EntityHandle
from .tx import Context
from .world import World, WorldTypes


trait Handler(Deinitable, Movable):
    """Handles events of a world (Go `Handler`)."""

    def handle_liquid_flow[
        T: WorldTypes
    ](
        mut self,
        mut tx: World[T],
        mut ctx: Context,
        from_: Pos,
        into: Pos,
        liquid: AnyBlock,
        replaced: AnyBlock,
    ):
        """Handles a liquid flowing from one position into another, replacing
        a block that may be a liquid (Go `HandleLiquidFlow`)."""
        pass

    def handle_liquid_decay[
        T: WorldTypes
    ](
        mut self,
        mut tx: World[T],
        mut ctx: Context,
        pos: Pos,
        before: AnyBlock,
        after: Optional[AnyBlock],
    ):
        """Handles a liquid without a source decaying; `after` is None if it
        disappears (Go `HandleLiquidDecay`)."""
        pass

    def handle_liquid_harden[
        T: WorldTypes
    ](
        mut self,
        mut tx: World[T],
        mut ctx: Context,
        hardened_pos: Pos,
        liquid_hardened: AnyBlock,
        other_liquid: AnyBlock,
        new_block: AnyBlock,
    ):
        """Handles a liquid turning solid next to another liquid (Go
        `HandleLiquidHarden`)."""
        pass

    def handle_leaves_decay[
        T: WorldTypes
    ](mut self, mut tx: World[T], mut ctx: Context, pos: Pos):
        """Handles leaves decaying (Go `HandleLeavesDecay`)."""
        pass

    def handle_fire_spread[
        T: WorldTypes
    ](mut self, mut tx: World[T], mut ctx: Context, from_: Pos, to: Pos):
        """Handles fire spreading from one block to another (Go
        `HandleFireSpread`)."""
        pass

    def handle_block_burn[
        T: WorldTypes
    ](mut self, mut tx: World[T], mut ctx: Context, pos: Pos):
        """Handles a block being destroyed by fire (Go `HandleBlockBurn`)."""
        pass

    def handle_crop_trample[
        T: WorldTypes
    ](mut self, mut tx: World[T], mut ctx: Context, pos: Pos):
        """Handles an entity trampling a crop (Go `HandleCropTrample`)."""
        pass

    def handle_explosion[
        T: WorldTypes
    ](
        mut self,
        mut tx: World[T],
        mut ctx: Context,
        src: Vec3,
        size: Float64,
        mut entities: List[UUID],
        mut blocks: List[Pos],
        mut item_drop_chance: Float64,
        mut spawn_fire: Bool,
    ):
        """Handles an explosion at `src`; the affected entities and blocks,
        the item drop chance and whether it spawns fire may be changed (Go
        `HandleExplosion`)."""
        pass

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
