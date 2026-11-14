"""Helpers shared by container blocks, from Dragonfly
`server/block/container.go` and the break handlers of its containers.

Go's `Container` interface becomes `world.block.Container` (the size) with
the inventory and viewers kept by the world (`World.inventory`,
`add_container_viewer`); see `world/block_entity.mojo`.
"""

from ..item.stack import Stack
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .cube.pos import Pos


def drop_contents[T: WorldTypes](pos: Pos, mut tx: World[T], at: Vec3):
    """Empties the container at `pos` and drops every stack at `at` (Go's
    `for _, i := range Inventory().Clear() { dropItem(...) }`)."""
    var found = tx.inventory(pos)
    if not found:
        return
    var inv = found.value().copy()
    for it in inv.clear():
        tx.drop_item(at, it)
    tx.set_inventory(pos, inv^)
