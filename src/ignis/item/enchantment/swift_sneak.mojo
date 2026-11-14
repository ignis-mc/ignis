"""`SwiftSneak`, ported from Dragonfly
`server/item/enchantment/swift_sneak.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import ITEM_LEGGINGS, SWIFT_SNEAK_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct SwiftSneak(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """SwiftSneak is a non-renewable enchantment that can be applied to
    leggings and allows the player to walk more quickly while sneaking
    (Go `enchantment.SwiftSneak`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (leggings)."""

    comptime ID: Int = SWIFT_SNEAK_ID
    """The enchantment ID (Go `item.RegisterEnchantment(37, SwiftSneak)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Swift Sneak`.
        """
        return "Swift Sneak"

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
        var min_cost = level * 25
        return (min_cost, min_cost + 50)

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
        return ItemFilter(kinds=ITEM_LEGGINGS)

    def treasure(self) -> Bool:
        """Reports whether the enchantment is a treasure enchantment, which
        enchanting tables never give (Go `Treasure`).

        Returns:
            True.
        """
        return True
