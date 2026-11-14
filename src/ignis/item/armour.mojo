"""Armour, ported from Dragonfly `server/item/armour.go`.

Go's `ArmourTier` interface has one implementation per material; here it
is a value type with a constant per material. The leather tier's dyed
colour is a field that is not part of the tier's identity: tiers compare
equal by material only, and `ArmourTier(i)` gives an undyed tier.
`armourTierRepairable` is `ArmourTier.repairable_by`.
"""

from ..internal.color import RGBA
from ..internal.enum import enum_name
from ..world.item import item_hash
from .stack import Stack


struct ArmourTier(Equatable, ImplicitlyCopyable, Writable):
    """The material a piece of armour is made of (Go `ArmourTier`)."""

    var _v: UInt8
    var colour: RGBA
    """The dyed colour of leather armour (Go `ArmourTierLeather.Colour`);
    transparent black when undyed. Ignored by the other tiers."""

    comptime LEATHER = ArmourTier(0)
    """Go `ArmourTierLeather{}`."""
    comptime COPPER = ArmourTier(1)
    """Go `ArmourTierCopper{}`."""
    comptime GOLD = ArmourTier(2)
    """Go `ArmourTierGold{}`."""
    comptime CHAIN = ArmourTier(3)
    """Go `ArmourTierChain{}`."""
    comptime IRON = ArmourTier(4)
    """Go `ArmourTierIron{}`."""
    comptime DIAMOND = ArmourTier(5)
    """Go `ArmourTierDiamond{}`."""
    comptime NETHERITE = ArmourTier(6)
    """Go `ArmourTierNetherite{}`."""

    def __init__(out self, v: Int):
        """Creates the tier with index `v` in `armour_tiers()`."""
        self._v = UInt8(v)
        self.colour = RGBA()

    def __eq__(self, other: Self) -> Bool:
        """Compares two tiers by material."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the tier's index in `armour_tiers()`."""
        return self._v

    def base_durability(self) -> Float64:
        """Returns the durability of a helmet of the tier (Go
        `BaseDurability`).
        """
        if self == Self.LEATHER:
            return 55
        if self == Self.COPPER:
            return 121
        if self == Self.GOLD:
            return 77
        if self == Self.CHAIN or self == Self.IRON:
            return 165
        if self == Self.DIAMOND:
            return 363
        return 407

    def toughness(self) -> Float64:
        """Returns the toughness of armour of the tier (Go `Toughness`)."""
        if self == Self.DIAMOND:
            return 2
        if self == Self.NETHERITE:
            return 3
        return 0

    def knock_back_resistance(self) -> Float64:
        """Returns the knock-back resistance of armour of the tier (Go
        `KnockBackResistance`).
        """
        return 0.1 if self == Self.NETHERITE else 0

    def enchantment_value(self) -> Int:
        """Returns the enchantability of armour of the tier (Go
        `EnchantmentValue`).
        """
        if self == Self.COPPER:
            return 8
        if self == Self.GOLD:
            return 25
        if self == Self.CHAIN:
            return 12
        if self == Self.IRON:
            return 9
        if self == Self.DIAMOND:
            return 10
        return 15

    def name(self) -> StaticString:
        """Returns the tier's name as used in item names (Go `Name`)."""
        return enum_name(
            "leather,copper,golden,chainmail,iron,diamond,netherite",
            Int(self._v),
        )

    def repairable_by(self, i: Stack) -> Bool:
        """Reports whether a stack repairs armour of the tier (Go
        `armourTierRepairable`).
        """
        var it = i.item()
        if not it:
            return False
        var kind = it.value().kind
        if self == Self.LEATHER:
            return kind == item_hash("Leather")
        if self == Self.COPPER:
            return kind == item_hash("CopperIngot")
        if self == Self.GOLD:
            return kind == item_hash("GoldIngot")
        if self == Self.CHAIN or self == Self.IRON:
            return kind == item_hash("IronIngot")
        if self == Self.DIAMOND:
            return kind == item_hash("Diamond")
        return kind == item_hash("NetheriteIngot")

    def write_to(self, mut writer: Some[Writer]):
        """Writes the tier's name."""
        writer.write(self.name())


def armour_tiers() -> List[ArmourTier]:
    """Returns every armour tier (Go `ArmourTiers`)."""
    var out = List[ArmourTier](capacity=7)
    for i in range(7):
        out.append(ArmourTier(i))
    return out^


trait Armour:
    """An item that may be worn as armour (Go `Armour`)."""

    def defence_points(self) -> Float64:
        """Returns the defence points the armour gives when worn."""
        ...

    def toughness(self) -> Float64:
        """Returns the toughness the armour gives when worn."""
        ...

    def knock_back_resistance(self) -> Float64:
        """Returns the share of knock-back the armour resists, 0 to 1."""
        ...


trait HelmetType(Armour):
    """Armour worn in the helmet slot (Go `HelmetType`)."""

    def helmet(self) -> Bool:
        """Marks the type as a helmet (Go `Helmet`)."""
        ...


trait ChestplateType(Armour):
    """Armour worn in the chestplate slot (Go `ChestplateType`)."""

    def chestplate(self) -> Bool:
        """Marks the type as a chestplate (Go `Chestplate`)."""
        ...


trait LeggingsType(Armour):
    """Armour worn in the leggings slot (Go `LeggingsType`)."""

    def leggings(self) -> Bool:
        """Marks the type as leggings (Go `Leggings`)."""
        ...


trait BootsType(Armour):
    """Armour worn in the boots slot (Go `BootsType`)."""

    def boots(self) -> Bool:
        """Marks the type as boots (Go `Boots`)."""
        ...
