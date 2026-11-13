"""`Flame`, ported from Dragonfly
`server/item/enchantment/flame.go`.
"""

from ..enchantment_rarity import EnchantmentRarity
from . import FLAME_ID, ITEM_BOW, EnchantmentType, ItemFilter


@fieldwise_init
struct Flame(Defaultable, EnchantmentType, ImplicitlyCopyable):
    """Flame turns your arrows into flaming arrows allowing you to set your
    targets on fire (Go `enchantment.Flame`).

    TODO(world-runtime): `CompatibleWithItem` takes a `world.Item`;
    `compatible_items` holds what it accepts (bows)."""

    comptime ID: Int = FLAME_ID
    """The enchantment ID (Go `item.RegisterEnchantment(21, Flame)`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            `Flame`.
        """
        return "Flame"

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
        return (20, 50)

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`).

        Returns:
            `EnchantmentRarity.RARE`.
        """
        return EnchantmentRarity.RARE

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
        return ItemFilter(kinds=ITEM_BOW)

    def burn_duration(self) -> Int:
        """Returns how long arrows set targets on fire (Go `BurnDuration`).

        Returns:
            5 seconds, in nanoseconds.
        """
        return 5 * 1_000_000_000
