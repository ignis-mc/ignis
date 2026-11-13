"""`CurseOfVanishing`, ported from Dragonfly
`server/item/enchantment/vanishing.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import (
    CURSE_OF_VANISHING_ID,
    ITEM_ARMOUR,
    ITEM_COMPASS,
    ITEM_DURABLE,
    ITEM_RECOVERY_COMPASS,
    EnchantmentType,
    ItemFilter,
)


@fieldwise_init
struct CurseOfVanishing(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """CurseOfVanishing is an enchantment that causes the item to disappear on
    death (Go `enchantment.CurseOfVanishing`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (armour, compasses and
    durable items)."""

    comptime ID: Int = CURSE_OF_VANISHING_ID
    """The enchantment ID (Go `item.RegisterEnchantment(28, CurseOfVanishing)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Curse of Vanishing`.
        """
        return "Curse of Vanishing"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`).

        Returns:
            1.
        """
        return 1

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`).

        Args:
            level: The enchantment level.

        Returns:
            The minimum and maximum cost.
        """
        return (25, 50)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`).

        Returns:
            `EnchantmentRarity.VERY_RARE`.
        """
        return EnchantmentRarity.VERY_RARE

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
        return ItemFilter(
            kinds=ITEM_ARMOUR
            | ITEM_COMPASS
            | ITEM_DURABLE
            | ITEM_RECOVERY_COMPASS
        )

    def treasure(self) -> Bool:
        """Reports whether the enchantment is a treasure enchantment, which
        enchanting tables never give (Go `Treasure`).

        Returns:
            True.
        """
        return True

    def curse(self) -> Bool:
        """Reports whether the enchantment is a curse (Go `Curse`).

        Returns:
            True.
        """
        return True
