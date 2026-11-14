"""Network item stacks, ported from `stackFromItem` and `stackToItem` in
Dragonfly `server/session/player.go`.
"""

from minecraft.nbt.decode import from_nbt
from minecraft.nbt.encode import to_nbt
from minecraft.nbt.nbt import LITTLE_ENDIAN, NBT
from minecraft.nbt.tree import Tree
from minecraft.protocol.item import ItemStack, ItemType

from ..block.air import Air
from ..block.register import VanillaBlocks
from ..item.nbt import read_nbt, write_nbt
from ..item.register import VanillaBlockItems, VanillaItems
from ..item.stack import Stack, has_nbt
from ..world.block_registry import BasicBlockRegistry
from ..world.item import AnyItem, ItemRegistry, ItemRuntimeID, RegisteredItem


def stack_from_item(
    br: BasicBlockRegistry, reg: ItemRegistry, it: Stack
) raises -> ItemStack:
    """Converts a stack to its network form (Go `stackFromItem`).

    Args:
        br: The block registry, for the runtime ID of block items.
        reg: The item registry.
        it: The stack.

    Returns:
        The network stack; a zero stack for an empty one.

    Raises:
        If the item is not registered or its NBT cannot be encoded.
    """
    if it.empty():
        return ItemStack()
    var item = it.item().value()
    var block_runtime_id = UInt32(0)
    var id: Optional[ItemRuntimeID]
    if item.block:
        var state = VanillaBlockItems.state_hash(item.kind, item.hash)
        if not state:
            raise Error(t"stack_from_item: unknown block item {item}")
        if case .Some(rid) = br.runtime_id_of(item.kind, state.value()):
            block_runtime_id = rid
        else:
            raise Error(t"stack_from_item: unregistered block {item}")
        id = None
        if case .Some(enc) = VanillaBlockItems.encode_item(
            item.kind, item.hash
        ):
            if case .Some(rid) = reg.runtime_id(enc.name):
                id = ItemRuntimeID(rid, enc.meta)
    else:
        id = reg.any_item_runtime_id(item)
    if not id:
        raise Error(t"stack_from_item: item without runtime ID {item}")
    var s = ItemStack()
    s.item_type = ItemType(id.value().runtime_id, UInt32(id.value().meta))
    s.count = UInt16(it.count())
    s.block_runtime_id = Int32(block_runtime_id)
    var st = it.copy()
    if not has_nbt(st.item_nbt()):
        # A stack made from a registered item rather than a typed value has
        # no item NBT yet; Go encodes the item value on every send.
        var data = _item_nbt(item, Tree())
        if case .Some(ref d) = data:
            st = st.with_item_nbt(d.copy())
    var tree = write_nbt(st)
    if len(tree.children(tree.root())) != 0:
        s.nbt_data = to_nbt(tree, LITTLE_ENDIAN)
    else:
        s.nbt_data = NBT(List[UInt8](), LITTLE_ENDIAN)
    return s^


def stack_to_item(
    br: BasicBlockRegistry, reg: ItemRegistry, it: ItemStack
) raises -> Stack:
    """Converts a network stack back to a stack (Go `stackToItem`).

    An unknown item becomes air; a block runtime ID, when set, decides the
    item: the block if its type is an item, air otherwise.

    Args:
        br: The block registry.
        reg: The item registry.
        it: The network stack.

    Returns:
        The stack.

    Raises:
        If the stack's NBT is malformed.
    """
    var t: Optional[RegisteredItem] = reg.item_by_runtime_id(
        it.item_type.network_id, Int16(it.item_type.metadata_value)
    )
    if it.block_runtime_id > 0:
        t = None
        var rid = UInt32(it.block_runtime_id)
        if rid < UInt32(br.block_count()):
            t = VanillaBlocks.block_item(br.kind(rid), br.state_hash(rid))
    var s: Stack
    var data = from_nbt(it.nbt_data)
    if case .Some(found) = t:
        s = Stack(found, Int(it.count))
        # Go `nbter.DecodeNBT(it.NBTData)` on an NBTer item.
        if has_nbt(data):
            if case .Some(ref d) = _item_nbt(found.item, data):
                s = s.with_item_nbt(d.copy())
    else:
        s = Stack(Air(), Int(it.count))
    return read_nbt(data, s)


def _item_nbt(it: AnyItem, data: Tree) raises -> Optional[Tree]:
    """The `EncodeNBT` of an item after decoding `data` into it, or None if
    its type is not an `NBTer`."""
    if it.block:
        return VanillaBlockItems.item_nbt(it.kind, it.hash, data)
    return VanillaItems.item_nbt(it.kind, it.hash, data)
