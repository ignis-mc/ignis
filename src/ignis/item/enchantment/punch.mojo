"""`Punch`, ported from Dragonfly
`server/item/enchantment/punch.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import ITEM_BOW, PUNCH_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Punch(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Punch increases the knock-back dealt when hitting a player or mob with a
    bow (Go `enchantment.Punch`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (bows)."""

    comptime ID: Int = PUNCH_ID
    """The enchantment ID (Go `item.RegisterEnchantment(20, Punch)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Punch`.
        """
        return "Punch"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`).

        Returns:
            2.
        """
        return 2

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`).

        Args:
            level: The enchantment level.

        Returns:
            The minimum and maximum cost.
        """
        var min_cost = 12 + (level - 1) * 20
        return (min_cost, min_cost + 25)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`).

        Returns:
            `EnchantmentRarity.RARE`.
        """
        return EnchantmentRarity.RARE

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

    def knockback_multiplier(self) -> Float64:
        """Returns the knockback added per level (Go `KnockBackMultiplier`).

        Returns:
            0.25.
        """
        return 0.25
