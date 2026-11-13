"""Enchantments: the `EnchantmentType` interface and registry of Dragonfly
`server/item/enchantment.go`, and the enchantment types of
`server/item/enchantment`.

Mojo cannot have a module and a package with the same name, so Go's
`item/enchantment.go` lives in this package's `__init__`; the enchantment on
a stack (Go `item.Enchantment`, a type with a level) is part of the item
stack port.

Go's `CompatibleWithEnchantment(t)` compares enchantment types; here types
are compared by ID. `CompatibleWithItem(i world.Item)` asks which interfaces
an item implements; until items are ported every type returns that as data,
an `ItemFilter`: TODO(world-runtime) implement `CompatibleWithItem` with it.
`ProtectionFactor` (Go `enchantment/damage.go`) needs `item.Enchantment` and
waits for it too.
"""

from ...block.break_info import ToolFilter
from ...world.damage_source import DamageSource
from ..enchantment_rarity import EnchantmentRarity

comptime PROTECTION_ID = 0
"""The ID of `Protection`."""
comptime FIRE_PROTECTION_ID = 1
"""The ID of `FireProtection`."""
comptime FEATHER_FALLING_ID = 2
"""The ID of `FeatherFalling`."""
comptime BLAST_PROTECTION_ID = 3
"""The ID of `BlastProtection`."""
comptime PROJECTILE_PROTECTION_ID = 4
"""The ID of `ProjectileProtection`."""
comptime THORNS_ID = 5
"""The ID of `Thorns`."""
comptime RESPIRATION_ID = 6
"""The ID of `Respiration`."""
comptime DEPTH_STRIDER_ID = 7
"""The ID of `DepthStrider`."""
comptime AQUA_AFFINITY_ID = 8
"""The ID of `AquaAffinity`."""
comptime SHARPNESS_ID = 9
"""The ID of `Sharpness`."""
comptime KNOCKBACK_ID = 12
"""The ID of `Knockback`."""
comptime FIRE_ASPECT_ID = 13
"""The ID of `FireAspect`."""
comptime EFFICIENCY_ID = 15
"""The ID of `Efficiency`."""
comptime SILK_TOUCH_ID = 16
"""The ID of `SilkTouch`."""
comptime UNBREAKING_ID = 17
"""The ID of `Unbreaking`."""
comptime FORTUNE_ID = 18
"""The ID of `Fortune`."""
comptime POWER_ID = 19
"""The ID of `Power`."""
comptime PUNCH_ID = 20
"""The ID of `Punch`."""
comptime FLAME_ID = 21
"""The ID of `Flame`."""
comptime INFINITY_ID = 22
"""The ID of `Infinity`."""
comptime MENDING_ID = 26
"""The ID of `Mending`."""
comptime CURSE_OF_VANISHING_ID = 28
"""The ID of `CurseOfVanishing`."""
comptime MULTISHOT_ID = 33
"""The ID of `Multishot`."""
comptime PIERCING_ID = 34
"""The ID of `Piercing`."""
comptime QUICK_CHARGE_ID = 35
"""The ID of `QuickCharge`."""
comptime SOUL_SPEED_ID = 36
"""The ID of `SoulSpeed`."""
comptime SWIFT_SNEAK_ID = 37
"""The ID of `SwiftSneak`."""

comptime ITEM_ARMOUR: UInt16 = 1 << 0
"""Items that are `item.Armour`."""
comptime ITEM_HELMET: UInt16 = 1 << 1
"""Items that are `item.HelmetType` with `Helmet()` true."""
comptime ITEM_LEGGINGS: UInt16 = 1 << 3
"""Items that are `item.LeggingsType` with `Leggings()` true."""
comptime ITEM_BOOTS: UInt16 = 1 << 4
"""Items that are `item.BootsType` with `Boots()` true."""
comptime ITEM_BOW: UInt16 = 1 << 5
"""`item.Bow`."""
comptime ITEM_CROSSBOW: UInt16 = 1 << 6
"""`item.Crossbow`."""
comptime ITEM_DURABLE: UInt16 = 1 << 7
"""Items that are `item.Durable`."""
comptime ITEM_COMPASS: UInt16 = 1 << 8
"""`item.Compass`."""
comptime ITEM_RECOVERY_COMPASS: UInt16 = 1 << 9
"""`item.RecoveryCompass`."""


struct ItemFilter(Equatable, ImplicitlyCopyable):
    """The items an enchantment applies to, as data (Go's
    `CompatibleWithItem` closures): an item matches if it has one of the
    `kinds`, or if it is a tool whose type `tools` accepts."""

    var kinds: UInt16
    """`ITEM_*` bits, any of which makes an item match."""
    var tools: ToolFilter
    """The tool types that match."""

    def __init__(
        out self, *, kinds: UInt16 = 0, tools: ToolFilter = ToolFilter()
    ):
        """Creates a filter.

        Args:
            kinds: `ITEM_*` bits.
            tools: The tool types that match.
        """
        self.kinds = kinds
        self.tools = tools

    def __eq__(self, other: Self) -> Bool:
        """Compares two filters.

        Args:
            other: The filter to compare with.

        Returns:
            True if both accept the same items.
        """
        return self.kinds == other.kinds and self.tools == other.tools

    def matches(self, kinds: UInt16, tool_type: Optional[Int]) -> Bool:
        """Reports whether an item matches.

        Args:
            kinds: The `ITEM_*` bits of the item.
            tool_type: The item's `TOOL_TYPE_*` if it is an `item.Tool`.

        Returns:
            True if the enchantment applies to the item.
        """
        if self.kinds & kinds != 0:
            return True
        if case .Some(t) = tool_type:
            return self.tools.matches(t, 0)
        return False


trait EnchantmentType(Copyable, Defaultable, Deinitable):
    """A type of enchantment (Go `item.EnchantmentType`)."""

    comptime ID: Int
    """The ID the enchantment is registered with (Go `EnchantmentID`)."""

    def name(self) -> String:
        """Returns the name of the enchantment (Go `Name`).

        Returns:
            The name.
        """
        ...

    def max_level(self) -> Int:
        """Returns the highest level of the enchantment (Go `MaxLevel`).

        Returns:
            The maximum level.
        """
        ...

    def cost(self, level: Int) -> Tuple[Int, Int]:
        """Returns the range of enchanting levels that can give the
        enchantment at a level (Go `Cost`).

        Args:
            level: The enchantment level.

        Returns:
            The minimum and maximum cost.
        """
        ...

    def rarity(self) -> EnchantmentRarity:
        """Returns the rarity of the enchantment (Go `Rarity`).

        Returns:
            The rarity.
        """
        ...

    def compatible_with_enchantment(self, id: Int) -> Bool:
        """Reports whether the enchantment can be on an item together with
        another (Go `CompatibleWithEnchantment`).

        Args:
            id: The ID of the other enchantment.

        Returns:
            True if they are compatible.
        """
        ...

    def compatible_items(self) -> ItemFilter:
        """Returns the items the enchantment applies to (the data of Go's
        `CompatibleWithItem`).

        Returns:
            The filter.
        """
        ...


trait AffectedDamageSource(DamageSource):
    """A damage source that protection enchantments other than plain
    protection may reduce (Go `enchantment.AffectedDamageSource`)."""

    def affected_by_enchantment(self, id: Int) -> Bool:
        """Reports whether an enchantment reduces the damage (Go
        `AffectedByEnchantment`, which takes the type).

        Args:
            id: The ID of the enchantment.

        Returns:
            True if the enchantment applies.
        """
        ...


struct EnchantmentSet[*Ts: EnchantmentType]:
    """A compile-time list of enchantment types with lookups by ID (Go's
    `enchantmentsMap` with `EnchantmentByID`).

    Parameters:
        Ts: The enchantment types, each with a distinct `ID`.
    """

    @staticmethod
    def contains(id: Int) -> Bool:
        """Reports whether an enchantment with the ID is in the set.

        Args:
            id: The enchantment ID.

        Returns:
            True if one of `Ts` has that ID.
        """
        comptime for i in range(len(Self.Ts)):
            if id == Self.Ts[i].ID:
                return True
        return False

    @staticmethod
    def ids() -> List[Int]:
        """Returns the IDs of the enchantments in the set.

        Returns:
            The IDs, in the order of `Ts`.
        """
        var out = List[Int]()
        comptime for i in range(len(Self.Ts)):
            out.append(Self.Ts[i].ID)
        return out^

    @staticmethod
    def name(id: Int) -> Optional[String]:
        """Returns the name of the enchantment with an ID.

        Args:
            id: The enchantment ID.

        Returns:
            The name, or None for an unknown ID.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            if id == T.ID:
                return T().name()
        return None

    @staticmethod
    def max_level(id: Int) -> Optional[Int]:
        """Returns the highest level of the enchantment with an ID.

        Args:
            id: The enchantment ID.

        Returns:
            The level, or None for an unknown ID.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            if id == T.ID:
                return T().max_level()
        return None

    @staticmethod
    def compatible(a: Int, b: Int) -> Bool:
        """Reports whether enchantment `a` accepts enchantment `b` on the
        same item (Go `a.CompatibleWithEnchantment(b)`).

        Args:
            a: The ID of the first enchantment.
            b: The ID of the second.

        Returns:
            True if compatible; False if `a` is unknown.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            if a == T.ID:
                return T().compatible_with_enchantment(b)
        return False
