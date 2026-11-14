"""`Infinity`, ported from Dragonfly
`server/item/enchantment/infinity.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import INFINITY_ID, ITEM_BOW, MENDING_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Infinity(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Infinity is an enchantment to bows that prevents regular arrows from
    being consumed when shot (Go `enchantment.Infinity`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (bows)."""

    comptime ID: Int = INFINITY_ID
    """The enchantment ID (Go `item.RegisterEnchantment(22, Infinity)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Infinity`.
        """
        return "Infinity"

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
        return (20, 50)

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
        return id != MENDING_ID

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`).

        Returns:
            The filter.
        """
        return ItemFilter(kinds=ITEM_BOW)

    def consumes_arrows(self) -> Bool:
        """Reports whether shooting consumes arrows (Go `ConsumesArrows`).

        Returns:
            False.
        """
        return False
