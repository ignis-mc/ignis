"""`DepthStrider`, ported from Dragonfly
`server/item/enchantment/depth_strider.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import DEPTH_STRIDER_ID, ITEM_BOOTS, EnchantmentType, ItemFilter


@fieldwise_init
struct DepthStrider(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """DepthStrider is a boot enchantment that increases underwater movement
    speed (Go `enchantment.DepthStrider`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (boots)."""

    comptime ID: Int = DEPTH_STRIDER_ID
    """The enchantment ID (Go `item.RegisterEnchantment(7, DepthStrider)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Depth Strider"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 3

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = level * 10
        return (min_cost, min_cost + 15)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`)."""
        return EnchantmentRarity.RARE

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type)."""
        return True

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`)."""
        return ItemFilter(kinds=ITEM_BOOTS)
