"""The creative inventory packet, ported from `creativeContent` and
`deleteDamage` in Dragonfly `server/session/player.go`."""

from minecraft.nbt.decode import from_nbt
from minecraft.nbt.encode import to_nbt
from minecraft.nbt.nbt import LITTLE_ENDIAN, NBT
from minecraft.protocol.creative import CreativeGroup, CreativeItem
from minecraft.protocol.item import ItemStack
from minecraft.protocol.packet.creative_content import CreativeContent

from ..item.creative.creative import Creative
from ..world.block_registry import BasicBlockRegistry
from ..world.item import ItemRegistry
from .item import stack_from_item


def creative_content(
    br: BasicBlockRegistry, reg: ItemRegistry, c: Creative
) raises -> CreativeContent:
    """Builds the `CreativeContent` packet of a creative inventory (Go
    `creativeContent`)."""
    var pk = CreativeContent()
    for ref g in c.groups():
        var group = CreativeGroup()
        group.category = g.category.uint8()
        group.name = g.name
        group.icon = delete_damage(stack_from_item(br, reg, g.icon))
        pk.groups.append(group^)
    var index = 0
    for ref i in c.items():
        var group = -1
        for j in range(len(c.groups())):
            if c.groups()[j].name == i.group:
                group = j
                break
        index += 1
        if group < 0:
            continue
        var it = CreativeItem()
        it.creative_item_network_id = UInt32(index)
        it.item = delete_damage(stack_from_item(br, reg, i.stack))
        it.group_index = UInt32(group)
        pk.items.append(it^)
    return pk^


def delete_damage(var st: ItemStack) raises -> ItemStack:
    """Strips the damage from a network stack (Go `deleteDamage`)."""
    if len(st.nbt_data.raw) == 0:
        return st^
    var tree = from_nbt(st.nbt_data)
    if tree.remove(tree.root(), "Damage"):
        if len(tree.children(tree.root())) == 0:
            st.nbt_data = NBT(List[UInt8](), LITTLE_ENDIAN)
        else:
            st.nbt_data = to_nbt(tree, LITTLE_ENDIAN)
    return st^
