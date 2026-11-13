"""`QuickCharge`, ported from Dragonfly
`server/item/enchantment/quick_charge.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import ITEM_CROSSBOW, QUICK_CHARGE_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct QuickCharge(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """QuickCharge is an enchantment for quickly reloading a crossbow (Go
    `enchantment.QuickCharge`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (crossbows)."""

    comptime ID: Int = QUICK_CHARGE_ID
    """The enchantment ID (Go `item.RegisterEnchantment(35, QuickCharge)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Quick Charge`.
        """
        return "Quick Charge"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`).

        Returns:
            3.
        """
        return 3

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`).

        Args:
            level: The enchantment level.

        Returns:
            The minimum and maximum cost.
        """
        var min_cost = 12 + (level - 1) * 20
        return (min_cost, 50)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`).

        Returns:
            `EnchantmentRarity.UNCOMMON`.
        """
        return EnchantmentRarity.UNCOMMON

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type).

        Args:
            id: The ID of the other enchantment.

        Returns:
            True if they are compatible.
        """
        return True

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`).

        Returns:
            The filter.
        """
        return ItemFilter(kinds=ITEM_CROSSBOW)

    def charge_duration(self, level: Int) -> Int:
        """Returns how long the crossbow takes to load (Go `ChargeDuration`).

        Args:
            level: The enchantment level.

        Returns:
            `1.25 - 0.25 * level` seconds, in nanoseconds (Go truncates the
            float to an integer duration).
        """
        return Int((1.25 - 0.25 * Float64(level)) * 1_000_000_000.0)
