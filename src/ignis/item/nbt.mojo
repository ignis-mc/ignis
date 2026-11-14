"""The NBT of item stacks, ported from Dragonfly `server/item/nbt.go`.

`write_nbt`/`read_nbt` are the network form of `WriteNBT` and `ReadNBT`;
`write_disk_nbt`/`read_disk_nbt` the disk form (`writeItemStack`,
`readItemStack`): `{Name, Damage, Block?, Count, tag?}`, with the damage in
`tag` as a short. Reading looks the item up by `Name` and `Damage`; Go
also decodes `Block` to pick a block item's state, which matters only for
block items with several registered states and is not done yet. Go writes
the tags into a map, so its key order is random; Ignis writes them in the
order `WriteNBT` adds them. User values
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

from ..world.block_registry import BasicBlockRegistry
from ..world.block_set import BlockTypes
from ..world.chunk.encoding import encode_disk_block_state
from ..world.item import EncodedItem, ItemRegistry
from .stack import Enchantment, Stack


def write_nbt(s: Stack) raises -> Tree:
    """Encodes the properties of a stack to the NBT sent with it (Go
    `WriteNBT(s, false)`)."""
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
    Tags of the wrong type are ignored, as Go's type assertions do."""
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


def _own_nbt(tag: Tree) raises -> Tree:
    """Returns the tags of an item's NBT that the stack itself does not
    read: the item's own NBT."""
    var out = Tree()
    for c in tag.children(tag.root()):
        var k = tag.name(c)
        if (
            k == "RepairCost"
            or k == "Damage"
            or k == "display"
            or k == "ench"
            or k == "Unbreakable"
        ):
            continue
        _ = out.put_tree(out.root(), k, tag, c)
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


def write_disk_nbt[
    B: BlockTypes
](br: BasicBlockRegistry, reg: ItemRegistry, s: Stack) raises -> Tree:
    """Encodes a stack for disk (Go `WriteNBT(s, true)`); an empty compound
    for an empty stack. Raises if the item has no name."""
    var t = Tree(TAG_COMPOUND)
    if s.empty():
        return t^
    var it = s.item().value()
    var enc: Optional[EncodedItem]
    if it.block:
        enc = B.encode_block_item(it.kind, it.hash)
    else:
        enc = reg.encode_item(it)
    if not enc:
        raise Error(t"write_disk_nbt: item without a name {it}")
    var tag = write_nbt(s)
    var root = t.root()
    _ = t.put_string(root, "Name", enc.value().name)
    _ = t.put_short(root, "Damage", enc.value().meta)
    if it.block:
        if case .Some(rid) = br.runtime_id_of(it.kind, it.hash):
            encode_disk_block_state(br, rid, t, t.put_compound(root, "Block"))
    _ = t.put_byte(root, "Count", UInt8(s.count()))
    var tr = tag.root()
    if len(tag.children(tr)) > 0:
        # Go's disk writeDamage stores the damage as a short.
        if case .Some(d) = tag.get(tr, "Damage"):
            if tag.type_of(d) == TAG_INT:
                var v = tag.as_int(d)
                _ = tag.remove(tr, "Damage")
                _ = tag.put_short(tr, "Damage", Int16(v))
        _ = t.put_tree(root, "tag", tag, tr)
    return t^


def read_disk_nbt[B: BlockTypes](reg: ItemRegistry, t: Tree, m: Tag) -> Stack:
    """Decodes a stack from disk (Go `ReadNBT(m, nil)`); an empty stack if
    the item is unknown or the data is malformed. A block item with NBT
    keeps its own tags (Go's `DecodeNBT` of an `NBTer` item)."""
    try:
        if t.type_of(m) != TAG_COMPOUND:
            return Stack()
        var name = String()
        var meta = Int16(0)
        var count = 0
        if case .Some(e) = t.get(m, "Name"):
            if t.type_of(e) == TAG_STRING:
                name = t.as_string(e)
        if case .Some(e) = t.get(m, "Damage"):
            if t.type_of(e) == TAG_SHORT:
                meta = t.as_short(e)
        if case .Some(e) = t.get(m, "Count"):
            if t.type_of(e) == TAG_BYTE:
                count = Int(t.as_byte(e))
        var found = reg.item_by_name(name, meta)
        if not found:
            return Stack()
        var s = Stack(found.value(), count)
        if case .Some(tag) = t.get(m, "tag"):
            if t.type_of(tag) != TAG_COMPOUND:
                return s^
            var sub = Tree(TAG_COMPOUND)
            for c in t.children(tag):
                _ = sub.put_tree(sub.root(), t.name(c), t, c)
            var sr = sub.root()
            if case .Some(d) = sub.get(sr, "Damage"):
                if sub.type_of(d) == TAG_SHORT:
                    var v = sub.as_short(d)
                    _ = sub.remove(sr, "Damage")
                    _ = sub.put_int(sr, "Damage", Int32(v))
            s = read_nbt(sub, s)
            if case .Some(it) = s.item():
                if it.block and B.block_entity_nbt(it.kind, it.hash):
                    s = s.with_item_nbt(_own_nbt(sub))
        return s^
    except:
        return Stack()
