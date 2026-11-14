"""Pickaxe, ported from Dragonfly `server/item/pickaxe.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .durability import DurabilityInfo, Repairable
from .enchantment import Enchantable
from .item import MaxCounter, Weapon
from .smelting_info import Fuel, FuelInfo, Smeltable, SmeltInfo
from .stack import Stack
from .tool import (
    TOOL_TIER_WOOD,
    TYPE_PICKAXE,
    Tool,
    ToolTier,
    ToolType,
    tool_tier_index,
    tool_tier_repairable,
    tool_tier_smelt_info,
    tool_tiers,
)


struct Pickaxe(
    Enchantable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    MaxCounter,
    Repairable,
    Smeltable,
    Tool,
    Weapon,
):
    """A tool generally used for mining stone-like blocks and ores at a higher
    speed and to obtain their drops."""

    comptime BASE_HASH: UInt64 = item_hash("Pickaxe")
    """`item_hash("Pickaxe")`."""

    var tier: ToolTier
    """The tier of the pickaxe, which decides its durability and speed."""

    def __init__(out self, *, tier: ToolTier = TOOL_TIER_WOOD):
        """Creates the item (Go `Pickaxe{Tier: t}`; Go's zero tier is invalid).
        """
        self.tier = tier

    def __eq__(self, other: Self) -> Bool:
        """Compares two items by tier."""
        return self.tier == other.tier

    def tool_type(self) -> ToolType:
        """Returns the tool type (Go `ToolType`)."""
        return TYPE_PICKAXE

    def harvest_level(self) -> Int:
        """Returns the tier's harvest level (Go `HarvestLevel`)."""
        return self.tier.harvest_level

    def base_mining_efficiency(self, block_kind: UInt64) -> Float64:
        """Returns the tier's mining efficiency (Go `BaseMiningEfficiency`)."""
        return self.tier.base_mining_efficiency

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def attack_damage(self) -> Float64:
        """Returns the attack damage (Go `AttackDamage`)."""
        return self.tier.base_attack_damage + 1

    def enchantment_value(self) -> Int:
        """Returns the tier's enchantability (Go `EnchantmentValue`)."""
        return self.tier.enchantment_value

    def durability_info(self) -> DurabilityInfo:
        """Returns the durability info (Go `DurabilityInfo`)."""
        return DurabilityInfo(
            max_durability=self.tier.durability,
            attack_durability=2,
            break_durability=1,
            persistent=False,
        )

    def repairable_by(self, i: Stack) -> Bool:
        """Reports whether a stack repairs the pickaxe (Go `RepairableBy`)."""
        return tool_tier_repairable(self.tier, i)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return tool_tier_smelt_info(self.tier)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): 10 s for wooden tools."""
        if self.tier == TOOL_TIER_WOOD:
            return FuelInfo(10000)
        return FuelInfo()

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.tier.name}_pickaxe"), 0)

    def hash(self) -> UInt64:
        """Returns the item hash: the tier's index in `tool_tiers()`."""
        return UInt64(tool_tier_index(self.tier))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(tier=tool_tiers()[Int(hash)])

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every tier."""
        var out = List[Self]()
        for t in tool_tiers():
            out.append(Self(tier=t))
        return out^
