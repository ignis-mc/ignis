"""`AquaAffinity`, ported from Dragonfly
`server/item/enchantment/aqua_affinity.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import AQUA_AFFINITY_ID, ITEM_HELMET, EnchantmentType, ItemFilter


@fieldwise_init
struct AquaAffinity(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """AquaAffinity is a helmet enchantment that increases underwater mining
    speed (Go `enchantment.AquaAffinity`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (helmets)."""

    comptime ID: Int = AQUA_AFFINITY_ID
    """The enchantment ID (Go `item.RegisterEnchantment(8, AquaAffinity)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Aqua Affinity`.
        """
        return "Aqua Affinity"

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
        return (1, 41)

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
        return ItemFilter(kinds=ITEM_HELMET)
