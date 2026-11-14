"""`Piercing`, ported from Dragonfly
`server/item/enchantment/piercing.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import (
    ITEM_CROSSBOW,
    MULTISHOT_ID,
    PIERCING_ID,
    EnchantmentType,
    ItemFilter,
)


@fieldwise_init
struct Piercing(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Piercing is an enchantment that allows arrows to damage and pierce
    through multiple entities, including shields (Go
    `enchantment.Piercing`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (crossbows)."""

    comptime ID: Int = PIERCING_ID
    """The enchantment ID (Go `item.RegisterEnchantment(34, Piercing)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Piercing`.
        """
        return "Piercing"

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
        return (1 + (level - 1) * 10, 50)

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
        return id != MULTISHOT_ID

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`).

        Returns:
            The filter.
        """
        return ItemFilter(kinds=ITEM_CROSSBOW)

    def pierces(self) -> Bool:
        """Reports whether arrows pierce entities (Go `Pierces`).

        Returns:
            True.
        """
        return True
