"""`FireAspect`, ported from Dragonfly
`server/item/enchantment/fire_aspect.go`.
"""

from ...block.break_info import ToolFilter
from ..tool import TYPE_SWORD
from ..enchantment_rarity import EnchantmentRarity
from . import FIRE_ASPECT_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct FireAspect(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """FireAspect is a sword enchantment that sets the target on fire (Go
    `enchantment.FireAspect`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (swords)."""

    comptime ID: Int = FIRE_ASPECT_ID
    """The enchantment ID (Go `item.RegisterEnchantment(13, FireAspect)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Fire Aspect"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 2

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = 10 + (level - 1) * 20
        return (min_cost, min_cost + 50)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`)."""
        return EnchantmentRarity.RARE

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type)."""
        return True

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`)."""
        return ItemFilter(tools=ToolFilter(TYPE_SWORD))

    def duration(self, level: Int) -> Int:
        """Returns how long a hit sets the target on fire (Go `Duration`)."""
        return 4 * level * 1_000_000_000
