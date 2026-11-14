"""`Unbreaking`, ported from Dragonfly
`server/item/enchantment/unbreaking.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import ITEM_DURABLE, UNBREAKING_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Unbreaking(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Unbreaking is an enchantment that gives a chance for an item to avoid
    durability reduction when it is used, effectively increasing the
    item's durability (Go `enchantment.Unbreaking`).

    TODO(world-runtime): `Reduce` (random durability loss) and
    `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (durable items)."""

    comptime ID: Int = UNBREAKING_ID
    """The enchantment ID (Go `item.RegisterEnchantment(17, Unbreaking)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Unbreaking"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 3

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = 5 + 8 * (level - 1)
        return (min_cost, min_cost + 50)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`)."""
        return EnchantmentRarity.UNCOMMON

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type)."""
        return True

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`)."""
        return ItemFilter(kinds=ITEM_DURABLE)
