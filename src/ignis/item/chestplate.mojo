"""Chestplate, ported from Dragonfly `server/item/chestplate.go`.

The tier's leather colour and the trim are NBT data: compared by `__eq__`
but not hashed, so `from_hash` gives an undyed, untrimmed piece.

`Use` (Go `ctx.SwapHeldWithArmour(1)`) is in `server.use.use_item`.
"""

from minecraft.nbt.nbt import TAG_INT
from minecraft.nbt.tree import Tag, Tree

from ..internal.color import RGBA
from ..world.block import NBTer
from ..world.item import EncodedItem, Item, item_hash
from .armour import (
    ArmourTier,
    ChestplateType,
    armour_tiers,
    int32_from_rgba,
    rgba_from_int32,
)
from .armour_trim import ArmourTrim, read_trim, write_trim
from .copper_nugget import CopperNugget
from .durability import DurabilityInfo, Repairable
from .enchantment import Enchantable
from .gold_nugget import GoldNugget
from .iron_nugget import IronNugget
from .item import MaxCounter
from .smelting_info import Smeltable, SmeltInfo
from .stack import Stack


struct Chestplate(
    ChestplateType,
    Enchantable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    MaxCounter,
    NBTer,
    Repairable,
    Smeltable,
):
    """A defensive item that may be worn in the chestplate slot."""

    comptime BASE_HASH: UInt64 = item_hash("Chestplate")
    """`item_hash("Chestplate")`."""

    var tier: ArmourTier
    """The material the chestplate is made of."""
    var trim: ArmourTrim
    """The trim applied to the chestplate."""

    def __init__(
        out self,
        *,
        tier: ArmourTier = ArmourTier.LEATHER,
        trim: ArmourTrim = ArmourTrim(),
    ):
        """Creates the item; omitted fields take Go zero values."""
        self.tier = tier
        self.trim = trim

    def __eq__(self, other: Self) -> Bool:
        """Compares two items, including colour and trim."""
        return (
            self.tier == other.tier
            and self.tier.colour == other.tier.colour
            and self.trim == other.trim
        )

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`): 1."""
        return 1

    def defence_points(self) -> Float64:
        """Returns the defence points of the tier (Go `DefencePoints`)."""
        if self.tier == ArmourTier.LEATHER:
            return 3
        if self.tier == ArmourTier.COPPER:
            return 4
        if self.tier == ArmourTier.GOLD or self.tier == ArmourTier.CHAIN:
            return 5
        if self.tier == ArmourTier.IRON:
            return 6
        return 8

    def knock_back_resistance(self) -> Float64:
        """Returns the tier's knock-back resistance (Go
        `KnockBackResistance`)."""
        return self.tier.knock_back_resistance()

    def toughness(self) -> Float64:
        """Returns the tier's toughness (Go `Toughness`)."""
        return self.tier.toughness()

    def enchantment_value(self) -> Int:
        """Returns the tier's enchantability (Go `EnchantmentValue`)."""
        return self.tier.enchantment_value()

    def durability_info(self) -> DurabilityInfo:
        """Returns the durability info (Go `DurabilityInfo`)."""
        return DurabilityInfo(
            max_durability=Int(
                self.tier.base_durability() + self.tier.base_durability() / 2.2
            ),
            attack_durability=0,
            break_durability=0,
            persistent=False,
        )

    def smelt_info(self) -> SmeltInfo:
        """Returns the nugget smelting the chestplate gives (Go `SmeltInfo`)."""
        if self.tier == ArmourTier.IRON or self.tier == ArmourTier.CHAIN:
            return SmeltInfo(Stack(IronNugget(), 1), 0.1, ores=True)
        if self.tier == ArmourTier.GOLD:
            return SmeltInfo(Stack(GoldNugget(), 1), 0.1, ores=True)
        if self.tier == ArmourTier.COPPER:
            return SmeltInfo(Stack(CopperNugget(), 1), 0.1, ores=True)
        return SmeltInfo()

    def repairable_by(self, i: Stack) -> Bool:
        """Reports whether the stack repairs the tier (Go `RepairableBy`)."""
        return self.tier.repairable_by(i)

    def chestplate(self) -> Bool:
        """Marks the item as worn in the chestplate slot (Go `Chestplate`)."""
        return True

    def with_trim(self, trim: ArmourTrim) -> Self:
        """Returns the item with a trim (Go `WithTrim`)."""
        var c = self
        c.trim = trim
        return c

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem(
            String("minecraft:", self.tier.name(), "_chestplate"), 0
        )

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Reads the leather colour and the trim (Go `DecodeNBT`)."""
        var c = self
        if c.tier == ArmourTier.LEATHER:
            if case .Some(v) = tag.get(root, "customColor"):
                if tag.type_of(v) == TAG_INT:
                    c.tier.colour = rgba_from_int32(tag.as_int(v))
        c.trim = read_trim(tag, root)
        return c

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the leather colour and the trim (Go `EncodeNBT`)."""
        if self.tier == ArmourTier.LEATHER and self.tier.colour != RGBA():
            _ = tag.put_int(
                root, "customColor", int32_from_rgba(self.tier.colour)
            )
        write_trim(tag, root, self.trim)

    def hash(self) -> UInt64:
        """Returns the item hash: the tier's index."""
        return UInt64(self.tier.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(tier=ArmourTier(Int(hash)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every tier."""
        var out = List[Self]()
        for t in armour_tiers():
            out.append(Self(tier=t))
        return out^
