"""`SilkTouch`, ported from Dragonfly
`server/item/enchantment/silk_touch.go`.
"""

from ...block.break_info import ToolFilter
from ..tool import TYPE_AXE, TYPE_HOE, TYPE_PICKAXE, TYPE_SHEARS, TYPE_SHOVEL
from ..enchantment_rarity import EnchantmentRarity
from . import FORTUNE_ID, SILK_TOUCH_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct SilkTouch(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """SilkTouch is an enchantment that allows many blocks to drop themselves
    instead of their usual items when mined (Go
    `enchantment.SilkTouch`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (tools other than swords)."""

    comptime ID: Int = SILK_TOUCH_ID
    """The enchantment ID (Go `item.RegisterEnchantment(16, SilkTouch)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Silk Touch`.
        """
        return "Silk Touch"

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
        return (15, 65)

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
        return id != FORTUNE_ID

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
