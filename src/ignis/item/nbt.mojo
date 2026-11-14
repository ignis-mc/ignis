"""The NBT of item stacks, ported from Dragonfly `server/item/nbt.go`.

Only the network form of `WriteNBT` and `ReadNBT` is ported: the disk form
wraps the stack with its name, block and count and comes with the world
provider. Go writes the tags into a map, so its key order is random; Ignis
writes them in the order `WriteNBT` adds them. User values
(`dragonflyData`) are not ported, and `read_nbt` keeps enchantments of any
ID because the enchantment table is not ported yet (Go drops unknown IDs).
"""

from minecraft.nbt.nbt import (
    TAG_BYTE,
    TAG_COMPOUND,
    TAG_INT,
    TAG_LIST,
    TAG_SHORT,
    TAG_STRING,
)
from minecraft.nbt.tree import Tag, Tree

from .stack import Enchantment, Stack


def write_nbt(s: Stack) raises -> Tree:
    """Encodes the properties of a stack to the NBT sent with it (Go
    `WriteNBT(s, false)`).

    Args:
        s: The stack.

    Returns:
        A root compound; empty for an empty stack or one without
        properties.

    Raises:
        If the tree cannot be built.
    """
    var tag = Tree()
    if s.empty():
        return tag^
    var root = tag.root()
    # The item's own NBT (Go `EncodeNBT` of an `NBTer` item) comes first.
    var data = s.item_nbt()
    for c in data.children(data.root()):
        _ = tag.put_tree(root, data.name(c), data, c)
    # writeAnvilCost
    if s.anvil_cost() > 0:
        _ = tag.put_int(root, "RepairCost", Int32(s.anvil_cost()))
    # writeDamage: network stacks carry the damage as an int32.
    if s.info().durable():
        _ = tag.put_int(
            root, "Damage", Int32(s.max_durability() - s.durability())
        )
    # writeDisplay
    var name = s.custom_name()
    var lore = s.lore()
    if name.byte_length() != 0 or len(lore) != 0:
        var display = tag.put_compound(root, "display")
        if name.byte_length() != 0:
            _ = tag.put_string(display, "Name", name)
        if len(lore) != 0:
            var l = tag.put_list(display, "Lore", TAG_STRING)
            for line in lore:
                _ = tag.append_string(l, line)
    # writeEnchantments
    var enchants = s.enchantments()
    if len(enchants) != 0:
        var l = tag.put_list(root, "ench", TAG_COMPOUND)
        for e in enchants:
            var c = tag.append_compound(l)
            _ = tag.put_short(c, "id", e.id)
            _ = tag.put_short(c, "lvl", Int16(e.level))
    # writeUnbreakable
    if s.unbreakable():
        _ = tag.put_byte(root, "Unbreakable", 1)
    return tag^


def read_nbt(data: Tree, s: Stack) raises -> Stack:
    """Applies the NBT received with a stack to it (Go `ReadNBT(data, &s)`).
    Tags of the wrong type are ignored, as Go's type assertions do.

    Args:
        data: The stack's NBT; an empty tree changes nothing.
        s: The stack, already holding its item and count.

    Returns:
        The stack with damage, name, lore, enchantments, anvil cost and the
        unbreakable flag applied.

    Raises:
        If the tree is inconsistent.
    """
    if data.is_empty() or data.type_of(data.root()) != TAG_COMPOUND:
        return s.copy()
    var m = data.root()
    # readAnvilCost
    var out = s.with_anvil_cost(Int(_int(data, m, "RepairCost", TAG_INT)))
    # readDamage (network: int32)
    out = out.damage(Int(_int(data, m, "Damage", TAG_INT)))
    # readDisplay
    if case .Some(display) = data.get(m, "display"):
        if data.type_of(display) == TAG_COMPOUND:
            if case .Some(name) = data.get(display, "Name"):
                if data.type_of(name) == TAG_STRING:
                    out = out.with_custom_name(data.as_string(name))
            if case .Some(lore) = data.get(display, "Lore"):
                if (
                    data.type_of(lore) == TAG_LIST
                    and data.elem_type(lore) == TAG_STRING
                ):
                    var lines = List[String]()
                    for l in data.children(lore):
                        lines.append(data.as_string(l))
                    out = out.with_lore(lines^)
    # readEnchantments
    if case .Some(ench) = data.get(m, "ench"):
        if (
            data.type_of(ench) == TAG_LIST
            and data.elem_type(ench) == TAG_COMPOUND
        ):
            for e in data.children(ench):
                var id = Int16(_int(data, e, "id", TAG_SHORT))
                var lvl = max(Int16(_int(data, e, "lvl", TAG_SHORT)), 1)
                out = out.with_forced_enchantments([Enchantment(id, Int(lvl))])
    # readUnbreakable
    if _int(data, m, "Unbreakable", TAG_BYTE) == 1:
        out = out.as_unbreakable()
    return out^


def _int(data: Tree, t: Tag, key: StringSpan, tag_type: UInt8) raises -> Int64:
    """Reads an integer tag of exactly `tag_type`, or 0 (Go `nbtInt32`
    and friends)."""
    if case .Some(v) = data.get(t, key):
        var ty = data.type_of(v)
        if ty != tag_type:
            return 0
        if ty == TAG_BYTE:
            return Int64(data.as_byte(v))
        if ty == TAG_SHORT:
            return Int64(data.as_short(v))
        return Int64(data.as_int(v))
    return 0
