"""Armour inventories, ported from the slot part of Dragonfly
`server/item/inventory/armour.go`.

TODO(items): Go's slot validator (only helmets in slot 0, ...), damage
reduction, knock-back resistance and durability loss need the armour item
types of feat/items-1.
"""

from std.memory import ArcPointer

from ..stack import Stack
from .inventory import Inventory, StackIDs


struct Armour(Copyable):
    """The four armour slots of an entity (Go `inventory.Armour`)."""

    var inv: Inventory
    """The slots: helmet, chestplate, leggings, boots (Go `Inventory`)."""

    def __init__(out self):
        """Creates empty armour with its own stack ID source."""
        self.inv = Inventory(4)

    def __init__(out self, ids: ArcPointer[StackIDs]):
        """Creates empty armour drawing stack IDs from `ids`."""
        self.inv = Inventory(4, ids)

    def helmet(self) -> Stack:
        """Returns the helmet (Go `Helmet`)."""
        return self._get(0)

    def chestplate(self) -> Stack:
        """Returns the chestplate (Go `Chestplate`)."""
        return self._get(1)

    def leggings(self) -> Stack:
        """Returns the leggings (Go `Leggings`)."""
        return self._get(2)

    def boots(self) -> Stack:
        """Returns the boots (Go `Boots`)."""
        return self._get(3)

    def set(
        mut self,
        helmet: Stack,
        chestplate: Stack,
        leggings: Stack,
        boots: Stack,
    ):
        """Sets all four slots (Go `Set`)."""
        try:
            self.inv.set_item(0, helmet)
            self.inv.set_item(1, chestplate)
            self.inv.set_item(2, leggings)
            self.inv.set_item(3, boots)
        except:
            pass

    def _get(self, slot: Int) -> Stack:
        try:
            return self.inv.item(slot)
        except:
            return Stack()
