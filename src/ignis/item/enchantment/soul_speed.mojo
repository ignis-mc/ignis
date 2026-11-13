"""`SoulSpeed`, ported from Dragonfly
`server/item/enchantment/soul_speed.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import ITEM_BOOTS, SOUL_SPEED_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct SoulSpeed(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """SoulSpeed is an enchantment that can be applied on boots and allows the
    player to walk more quickly on soul sand or soul soil (Go
    `enchantment.SoulSpeed`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (boots)."""

    comptime ID: Int = SOUL_SPEED_ID
    """The enchantment ID (Go `item.RegisterEnchantment(36, SoulSpeed)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Soul Speed`.
        """
        return "Soul Speed"

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
        var min_cost = level * 10
        return (min_cost, min_cost + 15)

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
        return ItemFilter(kinds=ITEM_BOOTS)

    def treasure(self) -> Bool:
        """Reports whether the enchantment is a treasure enchantment, which
        enchanting tables never give (Go `Treasure`).

        Returns:
            True.
        """
        return True
