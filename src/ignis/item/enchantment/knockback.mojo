"""`Knockback`, ported from Dragonfly
`server/item/enchantment/knockback.go`.
"""

from ...block.break_info import ToolFilter
from ..tool import TYPE_SWORD
from ..enchantment_rarity import EnchantmentRarity
from . import KNOCKBACK_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Knockback(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Knockback is an enchantment to a sword that increases the sword's knock-
    back (Go `enchantment.Knockback`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (swords)."""

    comptime ID: Int = KNOCKBACK_ID
    """The enchantment ID (Go `item.RegisterEnchantment(12, Knockback)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Knockback"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 2

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = 5 + (level - 1) * 20
        return (min_cost, min_cost + 50)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`)."""
        return EnchantmentRarity.UNCOMMON

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type)."""
        return True

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`)."""
        return ItemFilter(tools=ToolFilter(TYPE_SWORD))

    def force(self, level: Int) -> Float64:
        """Returns the extra knockback force at a level (Go `Force`)."""
        return Float64(level) / 2
