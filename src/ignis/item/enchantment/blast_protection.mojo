"""`BlastProtection`, ported from Dragonfly
`server/item/enchantment/blast_protection.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import (
    BLAST_PROTECTION_ID,
    FIRE_PROTECTION_ID,
    ITEM_ARMOUR,
    PROJECTILE_PROTECTION_ID,
    PROTECTION_ID,
    EnchantmentType,
    ItemFilter,
)


@fieldwise_init
struct BlastProtection(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """BlastProtection is an armour enchantment that reduces damage from
    explosions (Go `enchantment.BlastProtection`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (armour)."""

    comptime ID: Int = BLAST_PROTECTION_ID
    """The enchantment ID (Go `item.RegisterEnchantment(3, BlastProtection)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Blast Protection"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 4

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = 5 + (level - 1) * 8
        return (min_cost, min_cost + 8)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`)."""
        return EnchantmentRarity.RARE

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type)."""
        return (
            id != FIRE_PROTECTION_ID
            and id != PROJECTILE_PROTECTION_ID
            and id != PROTECTION_ID
        )

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`)."""
        return ItemFilter(kinds=ITEM_ARMOUR)

    def modifier(self) -> Float64:
        """Returns the damage reduction per level (Go `Modifier`)."""
        return 0.08
