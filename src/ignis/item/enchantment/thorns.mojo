"""`Thorns`, `ThornsDamageSource`, ported from Dragonfly
`server/item/enchantment/thorns.go`.
"""

from ...world.damage_source import DamageSource
from ..enchantment_rarity import EnchantmentRarity
from . import ITEM_ARMOUR, THORNS_ID, EnchantmentType, ItemFilter


@fieldwise_init
struct Thorns(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Thorns is an enchantment that inflicts damage on attackers (Go
    `enchantment.Thorns`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (armour)."""

    comptime ID: Int = THORNS_ID
    """The enchantment ID (Go `item.RegisterEnchantment(5, Thorns)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Thorns`.
        """
        return "Thorns"

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`).

        Returns:
            3.
        """
        return 3

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`).

        Args:
            level: The enchantment level.

        Returns:
            The minimum and maximum cost.
        """
        var min_cost = 10 + 20 * (level - 1)
        return (min_cost, min_cost + 50)

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
        return True

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`).

        Returns:
            The filter.
        """
        return ItemFilter(kinds=ITEM_ARMOUR)


@fieldwise_init
struct ThornsDamageSource(DamageSource, ImplicitlyCopyable):
    """The damage source of the thorns enchantment (Go
    `enchantment.ThornsDamageSource`).

    TODO(world-runtime): the `Owner world.Entity` field."""

    def reduced_by_resistance(self) -> Bool:
        """See `DamageSource` (Go `ReducedByResistance`).

        Returns:
            True.
        """
        return True

    def reduced_by_armour(self) -> Bool:
        """See `DamageSource` (Go `ReducedByArmour`).

        Returns:
            False.
        """
        return False

    def fire(self) -> Bool:
        """See `DamageSource` (Go `Fire`).

        Returns:
            False.
        """
        return False

    def ignore_totem(self) -> Bool:
        """See `DamageSource` (Go `IgnoreTotem`).

        Returns:
            False.
        """
        return False
