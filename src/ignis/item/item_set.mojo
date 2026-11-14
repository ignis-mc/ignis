"""A compile-time list of item types, as `world.BlockSet` is for blocks. No
Dragonfly counterpart: it replaces calling methods on a `world.Item`
interface value.

An item of unknown type is an `AnyItem`, whose `kind` is the `BASE_HASH` of
its type. Behaviours only some items have (Go: `Usable`, `Consumable`, ...)
become traits, and their dispatchers loop over `Ts` with
`comptime if conforms_to(T, Trait)` exactly like `BlockSet` does.
"""

from minecraft.nbt.tree import Tree

from ..world.block import Block, NBTer
from ..world.item import (
    AnyItem,
    EncodedItem,
    Item,
    ItemRegistry,
    from_any_hash,
)
from .armour_trim import ArmourTrimMaterial
from .armour import (
    Armour,
    BootsType,
    ChestplateType,
    HelmetType,
    LeggingsType,
)
from .durability import DurabilityInfo, Durable, Repairable
from .enchantment import Enchantable
from .item import (
    BeaconPayment,
    Compostable,
    ConsumeInfo,
    Consumable,
    Cooldown,
    MaxCounter,
    OffHand,
    Weapon,
    item_info,
)
from .smelting_info import Fuel, FuelInfo, Smeltable, SmeltInfo
from .stack import Stack, has_nbt
from .tool import Tool, ToolInfo, ToolType


struct ItemSet[*Ts: Item]:
    """Static dispatch over the item types `Ts`."""

    @staticmethod
    def register_all(mut reg: ItemRegistry) raises:
        """Registers every item value of every type (Go `RegisterItem` calls
        in `register.go`).
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            for it in T.all_items():
                reg.register_item(it, item_info(it))

    @staticmethod
    def contains(kind: UInt64) -> Bool:
        """Reports whether a type with the base hash passed is in the set."""
        comptime for i in range(len(Self.Ts)):
            if kind == Self.Ts[i].BASE_HASH:
                return True
        return False

    @staticmethod
    def max_count(kind: UInt64, hash: UInt64) -> Optional[Int]:
        """Returns `MaxCounter.max_count` (Go `it.(MaxCounter)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, MaxCounter):
                if kind == T.BASE_HASH:
                    return _max_count(from_any_hash[T](hash))
        return None

    @staticmethod
    def durability_info(kind: UInt64, hash: UInt64) -> Optional[DurabilityInfo]:
        """Returns `Durable.durability_info` (Go `it.(Durable)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Durable):
                if kind == T.BASE_HASH:
                    return _durability_info(from_any_hash[T](hash))
        return None

    @staticmethod
    def tool_type(kind: UInt64, hash: UInt64) -> Optional[ToolType]:
        """Returns `Tool.tool_type` (Go `it.(Tool)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Tool):
                if kind == T.BASE_HASH:
                    return _tool_type(from_any_hash[T](hash))
        return None

    @staticmethod
    def harvest_level(kind: UInt64, hash: UInt64) -> Optional[Int]:
        """Returns `Tool.harvest_level` (Go `it.(Tool)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Tool):
                if kind == T.BASE_HASH:
                    return _harvest_level(from_any_hash[T](hash))
        return None

    @staticmethod
    def defence_points(kind: UInt64, hash: UInt64) -> Optional[Float64]:
        """Returns `Armour.defence_points` (Go `it.(Armour)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Armour):
                if kind == T.BASE_HASH:
                    return _defence_points(from_any_hash[T](hash))
        return None

    @staticmethod
    def toughness(kind: UInt64, hash: UInt64) -> Optional[Float64]:
        """Returns `Armour.toughness` (Go `it.(Armour)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Armour):
                if kind == T.BASE_HASH:
                    return _toughness(from_any_hash[T](hash))
        return None

    @staticmethod
    def knock_back_resistance(kind: UInt64, hash: UInt64) -> Optional[Float64]:
        """Returns `Armour.knock_back_resistance` (Go `it.(Armour)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Armour):
                if kind == T.BASE_HASH:
                    return _knock_back_resistance(from_any_hash[T](hash))
        return None

    @staticmethod
    def always_consumable(kind: UInt64, hash: UInt64) -> Optional[Bool]:
        """Returns `Consumable.always_consumable` (Go `it.(Consumable)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Consumable):
                if kind == T.BASE_HASH:
                    return _always_consumable(from_any_hash[T](hash))
        return None

    @staticmethod
    def consume_duration(kind: UInt64, hash: UInt64) -> Optional[Int]:
        """Returns `Consumable.consume_duration` (Go `it.(Consumable)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Consumable):
                if kind == T.BASE_HASH:
                    return _consume_duration(from_any_hash[T](hash))
        return None

    @staticmethod
    def consume_info(kind: UInt64, hash: UInt64) -> Optional[ConsumeInfo]:
        """Returns `Consumable.consume_info` (Go `it.(Consumable)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Consumable):
                if kind == T.BASE_HASH:
                    return _consume_info(from_any_hash[T](hash))
        return None

    @staticmethod
    def fuel_info(kind: UInt64, hash: UInt64) -> Optional[FuelInfo]:
        """Returns `Fuel.fuel_info` (Go `it.(Fuel)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Fuel):
                if kind == T.BASE_HASH:
                    return _fuel_info(from_any_hash[T](hash))
        return None

    @staticmethod
    def smelt_info(kind: UInt64, hash: UInt64) -> Optional[SmeltInfo]:
        """Returns `Smeltable.smelt_info` (Go `it.(Smeltable)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Smeltable):
                if kind == T.BASE_HASH:
                    return _smelt_info(from_any_hash[T](hash))
        return None

    @staticmethod
    def enchantment_value(kind: UInt64, hash: UInt64) -> Optional[Int]:
        """Returns `Enchantable.enchantment_value` (Go `it.(Enchantable)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Enchantable):
                if kind == T.BASE_HASH:
                    return _enchantment_value(from_any_hash[T](hash))
        return None

    @staticmethod
    def compost_chance(kind: UInt64, hash: UInt64) -> Optional[Float64]:
        """Returns `Compostable.compost_chance` (Go `it.(Compostable)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Compostable):
                if kind == T.BASE_HASH:
                    return _compost_chance(from_any_hash[T](hash))
        return None

    @staticmethod
    def off_hand(kind: UInt64, hash: UInt64) -> Optional[Bool]:
        """Returns `OffHand.off_hand` (Go `it.(OffHand)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, OffHand):
                if kind == T.BASE_HASH:
                    return _off_hand(from_any_hash[T](hash))
        return None

    @staticmethod
    def payable_for_beacon(kind: UInt64, hash: UInt64) -> Optional[Bool]:
        """Returns `BeaconPayment.payable_for_beacon` (Go `it.(BeaconPayment)`).
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, BeaconPayment):
                if kind == T.BASE_HASH:
                    return _payable_for_beacon(from_any_hash[T](hash))
        return None

    @staticmethod
    def attack_damage(kind: UInt64, hash: UInt64) -> Optional[Float64]:
        """Returns `Weapon.attack_damage` (Go `it.(Weapon)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Weapon):
                if kind == T.BASE_HASH:
                    return _attack_damage(from_any_hash[T](hash))
        return None

    @staticmethod
    def cooldown(kind: UInt64, hash: UInt64) -> Optional[Int]:
        """Returns `Cooldown.cooldown` (Go `it.(Cooldown)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Cooldown):
                if kind == T.BASE_HASH:
                    return _cooldown(from_any_hash[T](hash))
        return None

    @staticmethod
    def base_mining_efficiency(
        kind: UInt64, hash: UInt64, block_kind: UInt64
    ) -> Optional[Float64]:
        """Returns `Tool.base_mining_efficiency` of the item for a block
        (Go `it.(Tool)`).
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Tool):
                if kind == T.BASE_HASH:
                    return _base_mining_efficiency(
                        from_any_hash[T](hash), block_kind
                    )
        return None

    @staticmethod
    def armour_slot(kind: UInt64, hash: UInt64) -> Optional[Int]:
        """Returns the armour slot the item is worn in (Go
        `it.(HelmetType)` and the other slot interfaces).
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Armour):
                if kind == T.BASE_HASH:
                    comptime if conforms_to(T, HelmetType):
                        return 0
                    elif conforms_to(T, ChestplateType):
                        return 1
                    elif conforms_to(T, LeggingsType):
                        return 2
                    elif conforms_to(T, BootsType):
                        return 3
                    else:
                        return -1
        return None

    @staticmethod
    def repairable_by(kind: UInt64, hash: UInt64, i: Stack) -> Optional[Bool]:
        """Returns `Repairable.repairable_by` of the item (Go
        `it.(Repairable)`).
        """
        comptime for j in range(len(Self.Ts)):
            comptime T = Self.Ts[j]
            comptime if conforms_to(T, Repairable):
                if kind == T.BASE_HASH:
                    return _repairable_by(from_any_hash[T](hash), i)
        return None

    @staticmethod
    def item_nbt(
        kind: UInt64, hash: UInt64, data: Tree
    ) raises -> Optional[Tree]:
        """Returns the `EncodeNBT` of the item after decoding `data` into it
        (Go `it.(world.NBTer)`); an empty `data` gives the item's own NBT.
        None if the type is not an `NBTer`."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, NBTer):
                if kind == T.BASE_HASH:
                    return _item_nbt(from_any_hash[T](hash), data)
        return None

    @staticmethod
    def trim_material(kind: UInt64, hash: UInt64) -> Optional[StaticString]:
        """Returns `ArmourTrimMaterial.trim_material` (Go
        `it.(ArmourTrimMaterial)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, ArmourTrimMaterial):
                if kind == T.BASE_HASH:
                    return _trim_material(from_any_hash[T](hash))
        return None

    @staticmethod
    def material_colour(kind: UInt64, hash: UInt64) -> Optional[StaticString]:
        """Returns `ArmourTrimMaterial.material_colour` (Go
        `it.(ArmourTrimMaterial)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, ArmourTrimMaterial):
                if kind == T.BASE_HASH:
                    return _material_colour(from_any_hash[T](hash))
        return None

    @staticmethod
    def state_hash(kind: UInt64, hash: UInt64) -> Optional[UInt64]:
        """Returns the block state hash of a block item from its
        `AnyItem.hash`; None if no block type in the set has that kind."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Block):
                if kind == T.BASE_HASH:
                    return from_any_hash[T](hash).hash()
        return None

    @staticmethod
    def encode_item(kind: UInt64, hash: UInt64) -> Optional[EncodedItem]:
        """Encodes an item of any type in the set (Go `it.EncodeItem()`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            if kind == T.BASE_HASH:
                return from_any_hash[T](hash).encode_item()
        return None

    @staticmethod
    def tool(kind: UInt64, hash: UInt64, block_kind: UInt64) -> ToolInfo:
        """Returns an item's tool info for breaking a block of type
        `block_kind`, or Go's `ToolNone` for items that are not tools."""
        var t = Self.tool_type(kind, hash)
        if not t:
            return ToolInfo.none()
        return ToolInfo(
            t.value(),
            Self.harvest_level(kind, hash).or_else(0),
            Self.base_mining_efficiency(kind, hash, block_kind).or_else(1),
        )


def _max_count[T: MaxCounter](it: T) -> Int:
    return it.max_count()


def _durability_info[T: Durable](it: T) -> DurabilityInfo:
    return it.durability_info()


def _tool_type[T: Tool](it: T) -> ToolType:
    return it.tool_type()


def _harvest_level[T: Tool](it: T) -> Int:
    return it.harvest_level()


def _defence_points[T: Armour](it: T) -> Float64:
    return it.defence_points()


def _toughness[T: Armour](it: T) -> Float64:
    return it.toughness()


def _knock_back_resistance[T: Armour](it: T) -> Float64:
    return it.knock_back_resistance()


def _always_consumable[T: Consumable](it: T) -> Bool:
    return it.always_consumable()


def _consume_duration[T: Consumable](it: T) -> Int:
    return it.consume_duration()


def _consume_info[T: Consumable](it: T) -> ConsumeInfo:
    return it.consume_info()


def _fuel_info[T: Fuel](it: T) -> FuelInfo:
    return it.fuel_info()


def _smelt_info[T: Smeltable](it: T) -> SmeltInfo:
    return it.smelt_info()


def _enchantment_value[T: Enchantable](it: T) -> Int:
    return it.enchantment_value()


def _compost_chance[T: Compostable](it: T) -> Float64:
    return it.compost_chance()


def _off_hand[T: OffHand](it: T) -> Bool:
    return it.off_hand()


def _payable_for_beacon[T: BeaconPayment](it: T) -> Bool:
    return it.payable_for_beacon()


def _attack_damage[T: Weapon](it: T) -> Float64:
    return it.attack_damage()


def _cooldown[T: Cooldown](it: T) -> Int:
    return it.cooldown()


def _base_mining_efficiency[T: Tool](it: T, block_kind: UInt64) -> Float64:
    return it.base_mining_efficiency(block_kind)


def _repairable_by[T: Repairable](it: T, i: Stack) -> Bool:
    return it.repairable_by(i)


def _item_nbt[T: NBTer](it: T, data: Tree) raises -> Tree:
    var v = it.copy()
    if has_nbt(data):
        v = it.decode_nbt(data, data.root())
    var out = Tree()
    v.encode_nbt(out, out.root())
    return out^


def _trim_material[T: ArmourTrimMaterial](it: T) -> StaticString:
    return it.trim_material()


def _material_colour[T: ArmourTrimMaterial](it: T) -> StaticString:
    return it.material_colour()
