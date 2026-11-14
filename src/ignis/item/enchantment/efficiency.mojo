"""`Efficiency`, ported from Dragonfly
`server/item/enchantment/efficiency.go`.
"""

from ...block.break_info import ToolFilter
from ..tool import TYPE_AXE, TYPE_HOE, TYPE_PICKAXE, TYPE_SHEARS, TYPE_SHOVEL
from ..enchantment_rarity import EnchantmentRarity
from . import EFFICIENCY_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Efficiency(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Efficiency is an enchantment that increases mining speed (Go
    `enchantment.Efficiency`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (tools other than swords)."""

    comptime ID: Int = EFFICIENCY_ID
    """The enchantment ID (Go `item.RegisterEnchantment(15, Efficiency)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Efficiency`.
        """
        return "Efficiency"

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
        var min_cost = 1 + 10 * (level - 1)
        return (min_cost, min_cost + 50)

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
        return ItemFilter(
            tools=ToolFilter(
                TYPE_PICKAXE,
                TYPE_AXE,
                TYPE_HOE,
                TYPE_SHOVEL,
                TYPE_SHEARS,
            )
        )

    def addend(self, level: Int) -> Float64:
        """Returns the bonus the enchantment adds at a level (Go `Addend`).

        Args:
            level: The enchantment level.

        Returns:
            `Float64(level * level + 1)`.
        """
        return Float64(level * level + 1)
