"""Helpers shared by container blocks, from Dragonfly
`server/block/container.go` and the break handlers of its containers.

Go's `Container` interface becomes `world.block.Container` (the size) with
the inventory and viewers kept by the world (`World.inventory`,
`add_container_viewer`); see `world/block_entity.mojo`.
"""

from ..item.inventory.inventory import Inventory
from ..item.stack import Stack
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .chest import chest_halves
from .cube.pos import Pos
from .hash import HASH_CHEST


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


def container_positions[T: WorldTypes](pos: Pos, mut tx: World[T]) -> List[Pos]:
    """Returns the blocks whose inventories make up the container at `pos`:
    both halves of a double chest, left first (Go `Chest.Inventory` with
    `tryPair`), else `pos`."""
    var br = tx.block_registry()
    if br[].kind(tx.block(pos)) == HASH_CHEST:
        if case .Some(h) = chest_halves(pos, tx):
            return [h[0], h[1]]
    return [pos]


def read_container[
    T: WorldTypes
](at: List[Pos], mut tx: World[T]) -> Optional[Inventory]:
    """Returns the inventory of the blocks `container_positions` gave, the
    halves of a double chest joined into 54 slots."""
    if len(at) == 1:
        return tx.inventory(at[0])
    var both = Inventory(27 * len(at), tx.stack_ids())
    for h in range(len(at)):
        var half = tx.inventory(at[h])
        if not half:
            return None
        for i in range(half.value().size()):
            try:
                both.set_item(h * 27 + i, half.value().item(i))
            except:
                pass
    _ = both.take_changes()
    return both^


def write_container[
    T: WorldTypes
](at: List[Pos], mut inv: Inventory, mut tx: World[T]):
    """Stores the slots `inv` changed into the blocks `container_positions`
    gave; their viewers see them with `flush_container_changes`."""
    if len(at) == 1:
        tx.set_inventory(at[0], inv.copy())
        _ = inv.take_changes()
        return
    var slots = inv.take_changes()
    for h in range(len(at)):
        var half = tx.inventory(at[h])
        if not half:
            continue
        var part = half.value().copy()
        for slot in slots:
            if slot // 27 != h:
                continue
            try:
                part.set_item(slot - h * 27, inv.item(slot))
            except:
                pass
        tx.set_inventory(at[h], part^)
