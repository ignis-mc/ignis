"""`FeatherFalling`, ported from Dragonfly
`server/item/enchantment/feather_falling.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import FEATHER_FALLING_ID, ITEM_BOOTS, EnchantmentType, ItemFilter


@fieldwise_init
struct FeatherFalling(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """FeatherFalling is an enchantment to boots that reduces fall damage. It
    does not affect falling speed (Go `enchantment.FeatherFalling`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (boots)."""

    comptime ID: Int = FEATHER_FALLING_ID
    """The enchantment ID (Go `item.RegisterEnchantment(2, FeatherFalling)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Feather Falling"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 4

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = 5 + (level - 1) * 6
        return (min_cost, min_cost + 6)

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
        return ItemFilter(kinds=ITEM_BOOTS)

    def modifier(self) -> Float64:
        """Returns the damage reduction per level (Go `Modifier`)."""
        return 0.12
