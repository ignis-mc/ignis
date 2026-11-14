"""Inventories in player data, ported from Dragonfly
`server/player/playerdb/inventory.go`.

A stored item is the little-endian NBT of `item.nbt.write_disk_nbt`.
"""

from minecraft.nbt.decode import decode
from minecraft.nbt.encode import encode
from minecraft.nbt.nbt import LITTLE_ENDIAN

from ...item.nbt import read_disk_nbt, write_disk_nbt
from ...item.stack import Stack
from ...session.inventory import Inventories
from ...world.block_registry import BasicBlockRegistry
from ...world.item import ItemRegistry
from .json import Data, Slot


def encode_item(
    br: BasicBlockRegistry, reg: ItemRegistry, s: Stack
) -> List[UInt8]:
    """Encodes a stack for storage (Go `encodeItem`); empty for an empty or
    unencodable stack (Go's nil)."""
    if s.empty():
        return List[UInt8]()
    try:
        return encode(write_disk_nbt(br, reg, s), LITTLE_ENDIAN)
    except:
        return List[UInt8]()


def decode_item(reg: ItemRegistry, data: List[UInt8]) -> Stack:
    """Decodes a stored stack (Go `decodeItem`); an empty stack if it
    cannot be read or its item is unknown."""
    if len(data) == 0:
        return Stack()
    try:
        var t = decode(Span(data), LITTLE_ENDIAN)
        return read_disk_nbt(reg, t, t.root())
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
