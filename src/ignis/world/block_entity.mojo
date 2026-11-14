"""Block entities of loaded chunks (Go `Column.BlockEntities`).

Go keeps the whole block value, inventory pointer included, in the column.
Ignis blocks are values rebuilt from their state hash, so a column keeps
per position the block's NBT (Go `EncodeNBT`) and, for containers, the live
inventory and the loaders viewing it. `World.block_as` decodes the NBT back
into the block; the inventory stays here so stack network IDs survive.
"""

from minecraft.nbt.nbt import TAG_BYTE, TAG_COMPOUND, TAG_LIST
from minecraft.nbt.tree import Tag, Tree

from ..item.inventory.inventory import Inventory
from ..item.nbt import read_disk_nbt, write_disk_nbt
from .block_registry import BasicBlockRegistry
from .block_set import BlockTypes
from .item import ItemRegistry
from .loader import LoaderID


struct BlockEntityState(Copyable):
    """The block entity at a position: NBT, inventory and viewers."""

    var kind: UInt64
    """The block type it belongs to; a new type replaces the entity."""
    var nbt: Tree
    """The block's NBT without its `Items` (Go `EncodeNBT`)."""
    var inv: Optional[Inventory]
    """The contents of a container."""
    var viewers: List[LoaderID]
    """The loaders that opened the container (Go's `viewers` map)."""
    var slot_offset: Int
    """Where the slots start in the window viewers see: 27 for the right
    half of a paired chest."""

    def __init__(out self, kind: UInt64, var nbt: Tree):
        """Creates an entity without inventory or viewers."""
        self.kind = kind
        self.nbt = nbt^
        self.inv = None
        self.viewers = List[LoaderID]()
        self.slot_offset = 0


def inv_to_nbt[
    B: BlockTypes
](
    br: BasicBlockRegistry,
    reg: ItemRegistry,
    inv: Inventory,
    mut tree: Tree,
    parent: Tag,
) raises:
    """Writes `Items` with every non-empty slot (Go `nbtconv.InvToNBT`)."""
    _ = tree.remove(parent, "Items")
    var l = tree.put_list(parent, "Items", TAG_COMPOUND)
    for i in range(inv.size()):
        var it = inv.item(i)
        if it.empty():
            continue
        var data = write_disk_nbt[B](br, reg, it)
        _ = data.put_byte(data.root(), "Slot", UInt8(i))
        _ = tree.append_tree(l, data, data.root())


def inv_from_nbt(
    reg: ItemRegistry, tree: Tree, parent: Tag, mut inv: Inventory
) raises:
    """Fills an inventory from `Items` (Go `nbtconv.InvFromNBT`); unknown
    items and slots out of range are skipped."""
    var items = tree.get(parent, "Items")
    if not items or tree.type_of(items.value()) != TAG_LIST:
        return
    for c in tree.children(items.value()):
        if tree.type_of(c) != TAG_COMPOUND:
            continue
        var it = read_disk_nbt(reg, tree, c)
        if it.empty():
            continue
        var slot = 0
        if case .Some(s) = tree.get(c, "Slot"):
            if tree.type_of(s) == TAG_BYTE:
                slot = Int(tree.as_byte(s))
        if slot < inv.size():
            inv.set_item(slot, it)
