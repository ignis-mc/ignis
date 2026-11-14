"""`Power`, ported from Dragonfly
`server/item/enchantment/power.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import ITEM_BOW, POWER_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Power(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Power is a bow enchantment which increases arrow damage (Go
    `enchantment.Power`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (bows)."""

    comptime ID: Int = POWER_ID
    """The enchantment ID (Go `item.RegisterEnchantment(19, Power)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Power`.
        """
        return "Power"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`).

        Returns:
            5.
        """
        return 5

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`).

        Args:
            level: The enchantment level.

        Returns:
            The minimum and maximum cost.
        """
        var min_cost = 1 + (level - 1) * 10
        return (min_cost, min_cost + 15)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`).

        Returns:
            `EnchantmentRarity.COMMON`.
        """
        return EnchantmentRarity.COMMON

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
        return ItemFilter(kinds=ITEM_BOW)

    def power_damage(self, level: Int) -> Float64:
        """Returns the extra arrow damage at a level (Go `PowerDamage`).

        Args:
            level: The enchantment level.

        Returns:
            `(level + 1) * 0.5`.
        """
        return Float64(level + 1) * 0.5
