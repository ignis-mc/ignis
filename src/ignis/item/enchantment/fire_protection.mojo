"""`FireProtection`, ported from Dragonfly
`server/item/enchantment/fire_protection.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import (
    BLAST_PROTECTION_ID,
    FIRE_PROTECTION_ID,
    ITEM_ARMOUR,
    PROJECTILE_PROTECTION_ID,
    PROTECTION_ID,
    EnchantmentType,
    ItemFilter,
)


@fieldwise_init
struct FireProtection(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """FireProtection is an armour enchantment that decreases fire damage (Go
    `enchantment.FireProtection`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (armour)."""

    comptime ID: Int = FIRE_PROTECTION_ID
    """The enchantment ID (Go `item.RegisterEnchantment(1, FireProtection)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Fire Protection`.
        """
        return "Fire Protection"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`).

        Returns:
            4.
        """
        return 4

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`).

        Args:
            level: The enchantment level.

        Returns:
            The minimum and maximum cost.
        """
        var min_cost = 10 + (level - 1) * 8
        return (min_cost, min_cost + 8)

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
        return (
            id != BLAST_PROTECTION_ID
            and id != PROJECTILE_PROTECTION_ID
            and id != PROTECTION_ID
        )

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`).

        Returns:
            The filter.
        """
        return ItemFilter(kinds=ITEM_ARMOUR)

    def modifier(self) -> Float64:
        """Returns the damage reduction per level (Go `Modifier`).

        Returns:
            0.08.
        """
        return 0.08
