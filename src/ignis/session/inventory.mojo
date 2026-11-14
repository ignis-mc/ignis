"""The inventories a session shows, from Dragonfly `server/session`:
the inventory fields of `session.go`, `invByID`, `sendInv`, `sendItem` and
`instanceFromItem` of `player.go`, and the inventories `player/conf.go`
creates.

Go's session points at the player's inventories; here the session owns
them (`Inventories`), so that copying a `Player` stays cheap. Containers
are addressed by kind (`INV_*`) instead of by pointer.
"""

from std.memory import ArcPointer

from minecraft.protocol.container import (
    CONTAINER_ARMOR,
    CONTAINER_COMBINED_HOT_BAR_AND_INVENTORY,
    CONTAINER_CRAFTING_INPUT,
    CONTAINER_CREATED_OUTPUT,
    CONTAINER_CURSOR,
    CONTAINER_HOT_BAR,
    CONTAINER_INVENTORY,
    CONTAINER_OFFHAND,
)
from minecraft.protocol.inventory import (
    WINDOW_ID_ARMOUR,
    WINDOW_ID_INVENTORY,
    WINDOW_ID_OFF_HAND,
    WINDOW_ID_UI,
)
from minecraft.protocol.item import ItemInstance
from minecraft.protocol.packet.inventory_content import InventoryContent
from minecraft.protocol.packet.inventory_slot import InventorySlot

from ..item.inventory.armour import Armour
from ..item.inventory.inventory import Inventory, StackIDs
from ..item.stack import Stack
from ..world.block_registry import BasicBlockRegistry
from ..world.item import ItemRegistry
from .item import stack_from_item

comptime INV_MAIN = 0
"""The 36 slots of the player's inventory, hotbar first."""
comptime INV_OFF_HAND = 1
"""The off-hand slot."""
comptime INV_ARMOUR = 2
"""The armour slots."""
comptime INV_UI = 3
"""The UI inventory: cursor, crafting grid and created output."""
comptime INV_ENDER_CHEST = 4
"""The ender chest."""


def inventory_kind(container_id: UInt8) -> Optional[Int]:
    """Returns the inventory a container ID addresses (Go `invByID`), for the
    containers that exist without an opened block."""
    if (
        container_id == CONTAINER_CRAFTING_INPUT
        or container_id == CONTAINER_CREATED_OUTPUT
        or container_id == CONTAINER_CURSOR
    ):
        return INV_UI
    if (
        container_id == CONTAINER_HOT_BAR
        or container_id == CONTAINER_INVENTORY
        or container_id == CONTAINER_COMBINED_HOT_BAR_AND_INVENTORY
    ):
        return INV_MAIN
    if container_id == CONTAINER_OFFHAND:
        return INV_OFF_HAND
    if container_id == CONTAINER_ARMOR:
        return INV_ARMOUR
    return None


def instance_from_item(
    br: BasicBlockRegistry, reg: ItemRegistry, it: Stack
) -> ItemInstance:
    """Returns a stack with its network ID (Go `instanceFromItem`); a stack
    that cannot be encoded is sent as empty."""
    var inst = ItemInstance()
    if it.empty():
        return inst^
    try:
        inst.stack = stack_from_item(br, reg, it)
        inst.stack_network_id = it.id()
    except:
        pass
    return inst^


struct Inventories(Copyable):
    """A player's inventories and held slot (Go `player.Config`'s
    inventories with the session's `ui`)."""

    var ids: ArcPointer[StackIDs]
    """The stack network ID source they share."""
    var inv: Inventory
    """The main inventory, 36 slots (Go `Inventory`)."""
    var off_hand: Inventory
    """The off-hand, 1 slot (Go `OffHand`)."""
    var armour: Armour
    """The armour (Go `Armour`)."""
    var ui: Inventory
    """The UI inventory, 54 slots (Go `ui`)."""
    var ender_chest: Inventory
    """The ender chest, 27 slots (Go `EnderChestInventory`)."""
    var held_slot: Int
    """The selected hotbar slot, 0 to 8 (Go `HeldSlot`)."""

    def __init__(out self):
        """Creates empty inventories (Go `Config.Apply` defaults)."""
        var ids = ArcPointer(StackIDs())
        self.inv = Inventory(36, ids)
        self.off_hand = Inventory(1, ids)
        self.armour = Armour(ids)
        self.ui = Inventory(54, ids)
        self.ender_chest = Inventory(27, ids)
        self.held_slot = 0
        self.ids = ids^

    def get(
        ref self, kind: Int
    ) -> ref[
        self.inv, self.off_hand, self.armour.inv, self.ui, self.ender_chest
    ] Inventory:
        """Returns the inventory of a kind (`INV_*`)."""
        if kind == INV_OFF_HAND:
            return self.off_hand
        if kind == INV_ARMOUR:
            return self.armour.inv
        if kind == INV_UI:
            return self.ui
        if kind == INV_ENDER_CHEST:
            return self.ender_chest
        return self.inv

    def held_item(self) -> Stack:
        """Returns the stack in the main hand (Go `HeldItems`' first value)."""
        try:
            return self.inv.item(self.held_slot)
        except:
            return Stack()

    def off_hand_item(self) -> Stack:
        """Returns the stack in the off-hand."""
        try:
            return self.off_hand.item(0)
        except:
            return Stack()

    def set_held_item(mut self, it: Stack):
        """Replaces the stack in the main hand (Go `SetHeldItems`' first
        argument)."""
        try:
            self.inv.set_item(self.held_slot, it)
        except:
            pass


def window_id(kind: Int) -> UInt32:
    """Returns the window ID an inventory is sent with (Go `sendInv` calls)."""
    if kind == INV_OFF_HAND:
        return UInt32(Int(WINDOW_ID_OFF_HAND))
    if kind == INV_ARMOUR:
        return UInt32(Int(WINDOW_ID_ARMOUR))
    if kind == INV_UI:
        return UInt32(Int(WINDOW_ID_UI))
    return UInt32(Int(WINDOW_ID_INVENTORY))


def inventory_content(
    br: BasicBlockRegistry, reg: ItemRegistry, inv: Inventory, window: UInt32
) -> InventoryContent:
    """Returns the packet with every slot of an inventory (Go `sendInv`)."""
    var pk = InventoryContent()
    pk.window_id = window
    for s in inv.slots():
        pk.content.append(instance_from_item(br, reg, s))
    return pk^


def inventory_slot(
    br: BasicBlockRegistry,
    reg: ItemRegistry,
    it: Stack,
    slot: Int,
    window: UInt32,
) -> InventorySlot:
    """Returns the packet that sets one slot (Go `sendItem`)."""
    var pk = InventorySlot()
    pk.window_id = window
    pk.slot = UInt32(slot)
    pk.new_item = instance_from_item(br, reg, it)
    return pk^
