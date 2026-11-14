"""`Mending`, ported from Dragonfly
`server/item/enchantment/mending.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import INFINITY_ID, ITEM_DURABLE, MENDING_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Mending(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Mending is an enchantment that repairs the item when experience orbs are
    collected (Go `enchantment.Mending`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (durable items)."""

    comptime ID: Int = MENDING_ID
    """The enchantment ID (Go `item.RegisterEnchantment(26, Mending)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Mending"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 1

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = level * 25
        return (min_cost, min_cost + 50)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`)."""
        return EnchantmentRarity.RARE

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type)."""
        return id != INFINITY_ID

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`)."""
        return ItemFilter(kinds=ITEM_DURABLE)

    def treasure(self) -> Bool:
        """Reports whether the enchantment is a treasure enchantment, which
        enchanting tables never give (Go `Treasure`)."""
        return True
