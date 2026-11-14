"""`Fortune`, ported from Dragonfly
`server/item/enchantment/fortune.go`.
"""

from ...block.break_info import ToolFilter
from ..tool import TYPE_AXE, TYPE_HOE, TYPE_PICKAXE, TYPE_SHOVEL
from ..enchantment_rarity import EnchantmentRarity
from . import FORTUNE_ID, SILK_TOUCH_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Fortune(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Fortune is an enchantment that gives a chance to receive more item drops
    from certain blocks (Go `enchantment.Fortune`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (pickaxes, shovels, axes
    and hoes)."""

    comptime ID: Int = FORTUNE_ID
    """The enchantment ID (Go `item.RegisterEnchantment(18, Fortune)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Fortune"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 3

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = 15 + (level - 1) * 9
        return (min_cost, min_cost + 50 + level)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`)."""
        return EnchantmentRarity.RARE

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type)."""
        return id != SILK_TOUCH_ID

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`)."""
        return ItemFilter(
            tools=ToolFilter(
                TYPE_PICKAXE,
                TYPE_SHOVEL,
                TYPE_AXE,
                TYPE_HOE,
            )
        )
