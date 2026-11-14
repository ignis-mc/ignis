"""Inventories in player data, ported from Dragonfly
`server/player/playerdb/inventory.go` with the disk form of Go's
`item.WriteNBT`/`ReadNBT` (`writeItemStack`/`readItemStack`).

A stored item is little-endian NBT `{Name, Damage, Count, Block?, tag?}`.
Reading looks the item up by `Name` and `Damage`; Go also decodes `Block`
to pick a block item's state, which matters only for block items with
several registered states, and is not done yet.
"""

from minecraft.nbt.decode import decode
from minecraft.nbt.encode import encode
from minecraft.nbt.nbt import LITTLE_ENDIAN, TAG_BYTE, TAG_INT, TAG_SHORT
from minecraft.nbt.tree import Tree

from ...block.register import VanillaBlocks
from ...item.nbt import read_nbt, write_nbt
from ...item.stack import Stack
from ...session.inventory import Inventories
from ...world.block_registry import BasicBlockRegistry
from ...world.chunk.encoding import encode_disk_block_state
from ...world.item import EncodedItem, ItemRegistry
from .json import Data, Slot


def encode_item(
    br: BasicBlockRegistry, reg: ItemRegistry, s: Stack
) -> List[UInt8]:
    """Encodes a stack for storage (Go `encodeItem`); empty for an empty or
    unencodable stack (Go's nil)."""
    if s.empty():
        return List[UInt8]()
    try:
        var it = s.item().value()
        var enc: Optional[EncodedItem]
        if it.block:
            enc = VanillaBlocks.encode_block_item(it.kind, it.hash)
        else:
            enc = reg.encode_item(it)
        if not enc:
            return List[UInt8]()
        var tag = write_nbt(s)
        var t = Tree()
        var root = t.root()
        _ = t.put_string(root, "Name", enc.value().name)
        _ = t.put_short(root, "Damage", enc.value().meta)
        if it.block:
            if case .Some(rid) = br.runtime_id_of(it.kind, it.hash):
                encode_disk_block_state(
                    br, rid, t, t.put_compound(root, "Block")
                )
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
        return encode(t, LITTLE_ENDIAN)
    except:
        return List[UInt8]()


def decode_item(reg: ItemRegistry, data: List[UInt8]) -> Stack:
    """Decodes a stored stack (Go `decodeItem`); an empty stack if it
    cannot be read or its item is unknown."""
    if len(data) == 0:
        return Stack()
    try:
        var t = decode(Span(data), LITTLE_ENDIAN)
        var root = t.root()
        var name = String()
        var meta = Int16(0)
        var count = 0
        if case .Some(e) = t.get(root, "Name"):
            name = t.as_string(e)
        if case .Some(e) = t.get(root, "Damage"):
            if t.type_of(e) == TAG_SHORT:
                meta = t.as_short(e)
        if case .Some(e) = t.get(root, "Count"):
            if t.type_of(e) == TAG_BYTE:
                count = Int(t.as_byte(e))
        var found = reg.item_by_name(name, meta)
        if not found:
            return Stack()
        var s = Stack(found.value(), count)
        if case .Some(tag) = t.get(root, "tag"):
            var sub = Tree()
            for c in t.children(tag):
                _ = sub.put_tree(sub.root(), t.name(c), t, c)
            var sr = sub.root()
            if case .Some(d) = sub.get(sr, "Damage"):
                if sub.type_of(d) == TAG_SHORT:
                    var v = sub.as_short(d)
                    _ = sub.remove(sr, "Damage")
                    _ = sub.put_int(sr, "Damage", Int32(v))
            s = read_nbt(sub, s)
        return s^
    except:
        return Stack()


def put_inventories(
    mut d: Data, br: BasicBlockRegistry, reg: ItemRegistry, invs: Inventories
):
    """Stores a player's inventories in their data (Go `toJson`'s
    `invToData` and `encodeItems` of the ender chest)."""
    d.items = _encode_slots(br, reg, invs.inv.slots())
    d.helmet = encode_item(br, reg, invs.armour.helmet())
    d.chestplate = encode_item(br, reg, invs.armour.chestplate())
    d.leggings = encode_item(br, reg, invs.armour.leggings())
    d.boots = encode_item(br, reg, invs.armour.boots())
    d.off_hand = encode_item(br, reg, invs.off_hand_item())
    d.main_hand_slot = UInt32(invs.held_slot)
    d.ender_chest = _encode_slots(br, reg, invs.ender_chest.slots())


def load_inventories(d: Data, reg: ItemRegistry, mut invs: Inventories):
    """Fills a player's inventories from their data (Go `fromJson`)."""
    try:
        for ref s in d.items:
            if s.slot >= 0 and s.slot < invs.inv.size():
                invs.inv.set_item(s.slot, decode_item(reg, s.item))
        for ref s in d.ender_chest:
            if s.slot >= 0 and s.slot < invs.ender_chest.size():
                invs.ender_chest.set_item(s.slot, decode_item(reg, s.item))
        invs.off_hand.set_item(0, decode_item(reg, d.off_hand))
    except:
        pass
    invs.armour.set(
        decode_item(reg, d.helmet),
        decode_item(reg, d.chestplate),
        decode_item(reg, d.leggings),
        decode_item(reg, d.boots),
    )
    if d.main_hand_slot <= 8:
        invs.held_slot = Int(d.main_hand_slot)
    _ = invs.inv.take_changes()
    _ = invs.ender_chest.take_changes()
    _ = invs.off_hand.take_changes()
    _ = invs.armour.inv.take_changes()


def _encode_slots(
    br: BasicBlockRegistry, reg: ItemRegistry, slots: List[Stack]
) -> List[Slot]:
    # Go `encodeItems`: empty and unencodable slots are left out.
    var out = List[Slot]()
    for i in range(len(slots)):
        var b = encode_item(br, reg, slots[i])
        if len(b) > 0:
            out.append(Slot(b^, i))
    return out^
