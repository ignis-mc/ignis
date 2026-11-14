"""`Sharpness`, ported from Dragonfly
`server/item/enchantment/sharpness.go`.
"""

from ...block.break_info import ToolFilter
from ..tool import TYPE_AXE, TYPE_SWORD
from ..enchantment_rarity import EnchantmentRarity
from . import SHARPNESS_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Sharpness(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Sharpness is an enchantment applied to a sword or axe that increases
    melee damage (Go `enchantment.Sharpness`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (swords and axes)."""

    comptime ID: Int = SHARPNESS_ID
    """The enchantment ID (Go `item.RegisterEnchantment(9, Sharpness)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Sharpness`.
        """
        return "Sharpness"

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
        var min_cost = 1 + (level - 1) * 11
        return (min_cost, min_cost + 20)

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
        return ItemFilter(tools=ToolFilter(TYPE_SWORD, TYPE_AXE))

    def addend(self, level: Int) -> Float64:
        """Returns the bonus the enchantment adds at a level (Go `Addend`).

        Args:
            level: The enchantment level.

        Returns:
            `Float64(level) * 1.25`.
        """
        return Float64(level) * 1.25
