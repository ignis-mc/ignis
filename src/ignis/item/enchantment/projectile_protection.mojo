"""`ProjectileProtection`, ported from Dragonfly
`server/item/enchantment/projectile_protection.go`.
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
struct ProjectileProtection(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """ProjectileProtection is an armour enchantment that reduces damage from
    projectiles (Go `enchantment.ProjectileProtection`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (armour)."""

    comptime ID: Int = PROJECTILE_PROTECTION_ID
    """The enchantment ID (Go `item.RegisterEnchantment(4, ProjectileProtection)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`)."""
        return "Projectile Protection"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`)."""
        return 4

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`)."""
        var min_cost = 3 + (level - 1) * 6
        return (min_cost, min_cost + 6)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`)."""
        return EnchantmentRarity.UNCOMMON

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`, which takes the type)."""
        return (
            id != BLAST_PROTECTION_ID
            and id != FIRE_PROTECTION_ID
            and id != PROTECTION_ID
        )

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`)."""
        return ItemFilter(kinds=ITEM_ARMOUR)

    def modifier(self) -> Float64:
        """Returns the damage reduction per level (Go `Modifier`)."""
        return 0.08
