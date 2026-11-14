"""Which enchantments fit which items: Go's `CompatibleWithItem` closures
need the item's interfaces (`item.Armour`, `item.Durable`, `item.Tool`,
...); here the item's `ITEM_*` bits are worked out from its type.
"""

from .boots import Boots
from .bow import Bow
from .chestplate import Chestplate
from .compass import Compass
from .crossbow import Crossbow
from .elytra import Elytra
from .enchantment import (
    ITEM_ARMOUR,
    ITEM_BOOTS,
    ITEM_BOW,
    ITEM_COMPASS,
    ITEM_CROSSBOW,
    ITEM_DURABLE,
    ITEM_HELMET,
    ITEM_LEGGINGS,
    ITEM_RECOVERY_COMPASS,
)
from .enchantment.register import VanillaEnchantments
from .helmet import Helmet
from .leggings import Leggings
from .recovery_compass import RecoveryCompass
from .register import VanillaItems
from .stack import Stack
from .turtle_shell import TurtleShell


def item_kinds(s: Stack) -> UInt16:
    """Returns the `ITEM_*` bits of a stack's item."""
    var out = UInt16(0)
    if s.empty():
        return out
    if s.info().durable():
        out |= ITEM_DURABLE
    var it = s.item().value()
    if it.block:
        return out
    var k = it.kind
    if k == Helmet.BASE_HASH or k == TurtleShell.BASE_HASH:
        out |= ITEM_ARMOUR | ITEM_HELMET
    elif k == Chestplate.BASE_HASH or k == Elytra.BASE_HASH:
        out |= ITEM_ARMOUR
    elif k == Leggings.BASE_HASH:
        out |= ITEM_ARMOUR | ITEM_LEGGINGS
    elif k == Boots.BASE_HASH:
        out |= ITEM_ARMOUR | ITEM_BOOTS
    elif k == Bow.BASE_HASH:
        out |= ITEM_BOW
    elif k == Crossbow.BASE_HASH:
        out |= ITEM_CROSSBOW
    elif k == Compass.BASE_HASH:
        out |= ITEM_COMPASS
    elif k == RecoveryCompass.BASE_HASH:
        out |= ITEM_RECOVERY_COMPASS
    return out


def compatible_with_item(id: Int, s: Stack) -> Bool:
    """Reports whether the enchantment with an ID applies to a stack's item
    (Go `EnchantmentType.CompatibleWithItem`)."""
    var f = VanillaEnchantments.compatible_items(id)
    if not f or s.empty():
        return False
    var it = s.item().value()
    var tool: Optional[Int] = None
    if not it.block:
        if case .Some(t) = VanillaItems.tool_type(it.kind, it.hash):
            tool = t.t
    return f.value().matches(item_kinds(s), tool)
