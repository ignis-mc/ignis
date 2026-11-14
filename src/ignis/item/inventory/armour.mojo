"""Armour inventories, ported from the slot part of Dragonfly
`server/item/inventory/armour.go`.

Damage reduction and knock-back resistance read the armour values of the
worn items through `VanillaItems`. TODO(items): Go's slot validator (only
helmets in slot 0, ...).
"""

from std.memory import ArcPointer

from ..enchantment import AffectedDamageSource
from ..enchantment.damage import protection_factor
from ..register import VanillaItems
from ..stack import Enchantment, Stack
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

    def damage_reduction[
        S: AffectedDamageSource
    ](self, dmg_in: Float64, src: S) -> Float64:
        """Returns how much of `dmg_in` the armour and its enchantments take
        away (Go `DamageReduction`)."""
        var dmg = dmg_in
        var defence_points = 0.0
        var toughness = 0.0
        var enchantments = List[Enchantment]()
        for it in self.inv.items():
            enchantments += it.enchantments()
            if case .Some(i) = it.item():
                if case .Some(d) = VanillaItems.defence_points(i.kind, i.hash):
                    defence_points += d
                if case .Some(t) = VanillaItems.toughness(i.kind, i.hash):
                    toughness += t
        dmg -= dmg * protection_factor(src, enchantments)
        if src.reduced_by_armour():
            # Each effective armour point takes 4%; effective points drop by
            # one per 2 damage, eased by toughness, to at least 20%.
            dmg -= (
                dmg
                * 0.04
                * max(
                    defence_points * 0.2,
                    defence_points - dmg / (2 + toughness / 4),
                )
            )
        return dmg_in - dmg

    def knock_back_resistance(self) -> Float64:
        """Returns the summed knock-back resistance of the armour (Go
        `KnockBackResistance`)."""
        var r = 0.0
        for it in self.inv.items():
            if case .Some(i) = it.item():
                if case .Some(k) = VanillaItems.knock_back_resistance(
                    i.kind, i.hash
                ):
                    r += k
        return r

    def highest_enchantment_level(self, id: Int) -> Int:
        """Returns the highest level of an enchantment on the armour (Go
        `HighestEnchantmentLevel`)."""
        var lvl = 0
        for it in self.inv.items():
            if case .Some(e) = it.enchantment(Int16(id)):
                lvl = max(lvl, e.level)
        return lvl
