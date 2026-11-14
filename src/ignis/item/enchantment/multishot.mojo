"""`Multishot`, ported from Dragonfly
`server/item/enchantment/multishot.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import (
    ITEM_CROSSBOW,
    MULTISHOT_ID,
    PIERCING_ID,
    EnchantmentType,
    ItemFilter,
)


@fieldwise_init
struct Multishot(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Multishot is an enchantment for crossbows that allow them to shoot three
    arrows or firework rockets at the cost of one (Go
    `enchantment.Multishot`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (crossbows)."""

    comptime ID: Int = MULTISHOT_ID
    """The enchantment ID (Go `item.RegisterEnchantment(33, Multishot)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Multishot"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 1

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        return (20, 50)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`)."""
        return EnchantmentRarity.RARE

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type)."""
        return id != PIERCING_ID

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`)."""
        return ItemFilter(kinds=ITEM_CROSSBOW)

    def multiple_projectiles(self) -> Bool:
        """Reports whether the crossbow shoots several projectiles (Go
        `MultipleProjectiles`)."""
        return True
