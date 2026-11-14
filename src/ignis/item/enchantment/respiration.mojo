"""`Respiration`, ported from Dragonfly
`server/item/enchantment/respiration.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import ITEM_HELMET, RESPIRATION_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Respiration(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Respiration extends underwater breathing time by +15 seconds per
    enchantment level in addition to the default time of 15 seconds (Go
    `enchantment.Respiration`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (helmets)."""

    comptime ID: Int = RESPIRATION_ID
    """The enchantment ID (Go `item.RegisterEnchantment(6, Respiration)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Respiration"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 3

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = 10 * level
        return (min_cost, min_cost + 30)

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
        return ItemFilter(kinds=ITEM_HELMET)

    def chance(self, level: Int) -> Float64:
        """Returns the chance not to lose air underwater (Go `Chance`)."""
        return Float64(level) / Float64(level + 1)
