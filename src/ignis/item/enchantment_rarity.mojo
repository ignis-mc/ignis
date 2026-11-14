"""Enchantment rarities, ported from Dragonfly
`server/item/enchantment_rarity.go`.
"""

from ..internal.enum import enum_name


struct EnchantmentRarity(Equatable, ImplicitlyCopyable):
    """How rare an enchantment is, which decides its cost in anvils and how
    often enchanting tables give it (Go `item.EnchantmentRarity`, an
    interface with four singletons)."""

    var _r: UInt8

    comptime COMMON = EnchantmentRarity(0)
    """Go `item.EnchantmentRarityCommon`."""
    comptime UNCOMMON = EnchantmentRarity(1)
    """Go `item.EnchantmentRarityUncommon`."""
    comptime RARE = EnchantmentRarity(2)
    """Go `item.EnchantmentRarityRare`."""
    comptime VERY_RARE = EnchantmentRarity(3)
    """Go `item.EnchantmentRarityVeryRare`."""

    def __init__(out self, r: Int):
        """Creates the rarity with an index.

        Args:
            r: 0 (common) to 3 (very rare).
        """
        self._r = UInt8(r)

    def __eq__(self, other: Self) -> Bool:
        """Compares two rarities.

        Args:
            other: The rarity to compare with.

        Returns:
            True if both are the same rarity.
        """
        return self._r == other._r

    def name(self) -> StaticString:
        """Returns the name of the rarity (Go `Name`).

        Returns:
            `Common`, `Uncommon`, `Rare` or `Very Rare`.
        """
        return enum_name("Common,Uncommon,Rare,Very Rare", Int(self._r))

    def cost(self) -> Int:
        """Returns the anvil cost multiplier of the rarity (Go `Cost`).

        Returns:
            1, 2, 4 or 8.
        """
        return 1 << Int(self._r)

    def weight(self) -> Int:
        """Returns the weight of the rarity when enchanting (Go `Weight`).

        Returns:
            10, 5, 2 or 1.
        """
        if self._r == 0:
            return 10
        if self._r == 1:
            return 5
        if self._r == 2:
            return 2
        return 1
