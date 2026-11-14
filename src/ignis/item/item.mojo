"""Item behaviours, ported from Dragonfly `server/item/item.go`.

Go's optional item interfaces become traits, which `ItemSet` dispatches
over (`item_set.mojo`). The data interfaces are ported in full:
`MaxCounter`, `OffHand`, `Weapon`, `Cooldown`, `BeaconPayment`,
`Compostable`, `Drinkable`, `Glinted`, `HandEquipped`, and `Consumable`
except for its `Consume`; with `Durable` and `Repairable`
(`durability.mojo`), `Tool` (`tool.mojo`), `Armour` (`armour.mojo`),
`Smeltable` and `Fuel` (`smelting_info.mojo`) and `Enchantable`
(`enchantment`).

Go's `Consume(tx, c Consumer) Stack` acts on the consumer; here every
consumable describes what it does as data (`ConsumeInfo`: food,
saturation, effects, removed effects and the stack left over), which the
player package applies.

TODO(player): `UsableOnBlock`, `UsableOnEntity`, `Usable`, `Throwable`,
`Releasable`, `Chargeable`, `Consumer`, `User`, `Carrier`, `Releaser`,
`UseContext` (`use.go`) and the `Use*`/`Release*`/`Charge*` methods of
each item.
"""

from ..entity.effect import Effect
from ..internal.color import RGBA
from ..world.item import Item, ItemInfo
from .durability import Durable, DurabilityInfo, Repairable
from .stack import Stack

comptime DEFAULT_CONSUME_DURATION: Int = 1610
"""The time consuming an item takes by default, in milliseconds (Go
`DefaultConsumeDuration`, 1.61 s)."""


trait MaxCounter:
    """An item with a maximum count other than 64 (Go `MaxCounter`)."""

    def max_count(self) -> Int:
        """Returns the maximum count of a stack of the item."""
        ...


trait OffHand:
    """An item that may be held in the off hand (Go `OffHand`)."""

    def off_hand(self) -> Bool:
        """Reports whether the item may be held in the off hand."""
        ...


@fieldwise_init
struct ConsumeEffect(Copyable, Equatable, Writable):
    """An effect consuming an item gives, with the chance that it does."""

    var effect: Effect
    """The effect."""
    var chance: Float64
    """The probability that consuming the item gives it, in (0, 1]; Go
    compares `rand.Float64()` with it."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes the effect as `id:level:duration_ms`."""
        writer.write(
            self.effect.type_id(),
            ":",
            self.effect.level(),
            ":",
            self.effect.duration() // 1_000_000,
        )


struct ConsumeInfo(Copyable, Defaultable, Equatable):
    """What consuming an item does, as data: the calls Go's `Consume` makes
    on the `Consumer` and the stack it returns."""

    var food: Int
    """The food points `Saturate` adds."""
    var saturation: Float64
    """The saturation points `Saturate` adds."""
    var effects: List[ConsumeEffect]
    """The effects `AddEffect` adds."""
    var removed_effects: List[Int]
    """The IDs of the effects `RemoveEffect` removes."""
    var removes_all_effects: Bool
    """Whether every effect of the consumer is removed (milk)."""
    var residue: Stack
    """The stack `Consume` returns (a bowl, a glass bottle), added to the
    consumer's inventory; empty for none."""

    def __init__(out self):
        """Creates the info of an item that does nothing when consumed."""
        self.food = 0
        self.saturation = 0
        self.effects = List[ConsumeEffect]()
        self.removed_effects = List[Int]()
        self.removes_all_effects = False
        self.residue = Stack()

    def __init__(
        out self,
        food: Int,
        saturation: Float64,
        var effects: List[ConsumeEffect] = [],
        var residue: Stack = Stack(),
    ):
        """Creates the info of a food (Go `c.Saturate(food, saturation)`
        followed by `AddEffect` calls).
        """
        self.food = food
        self.saturation = saturation
        self.effects = effects^
        self.removed_effects = List[Int]()
        self.removes_all_effects = False
        self.residue = residue^


trait Consumable:
    """An item that may be consumed by a player (Go `Consumable`).

    TODO(player): Go's `Consume(tx, c)`; `consume_info` describes it.
    """

    def always_consumable(self) -> Bool:
        """Reports whether the item may be consumed with a full food bar."""
        ...

    def consume_duration(self) -> Int:
        """Returns how long consuming the item takes, in milliseconds."""
        ...

    def consume_info(self) -> ConsumeInfo:
        """Returns what consuming the item does (the effect of Go's
        `Consume`).
        """
        ...


trait Drinkable:
    """A custom item that may be drunk (Go `Drinkable`)."""

    def drinkable(self) -> Bool:
        """Reports whether the item may be drunk."""
        ...


trait Glinted:
    """A custom item with a permanent enchantment glint (Go `Glinted`)."""

    def glinted(self) -> Bool:
        """Reports whether the item has a glint."""
        ...


trait HandEquipped:
    """An item held like a tool (Go `HandEquipped`)."""

    def hand_equipped(self) -> Bool:
        """Reports whether the item is hand equipped."""
        ...


trait Weapon:
    """An item with an attack damage other than an empty hand's (Go
    `Weapon`)."""

    def attack_damage(self) -> Float64:
        """Returns the attack damage of the item."""
        ...


trait Cooldown:
    """An item that has a cooldown (Go `Cooldown`)."""

    def cooldown(self) -> Int:
        """Returns the duration of the cooldown, in milliseconds."""
        ...


trait BeaconPayment:
    """An item that may pay for a beacon's effects (Go `BeaconPayment`)."""

    def payable_for_beacon(self) -> Bool:
        """Reports whether the item may pay for a beacon."""
        ...


trait Compostable:
    """An item that may fill a composter (Go `Compostable`)."""

    def compost_chance(self) -> Float64:
        """Returns the chance that the item adds a layer of compost."""
        ...


def int32_from_rgba(x: RGBA) -> Int32:
    """Packs a colour as ARGB into an int32 (Go `int32FromRGBA`); black is
    opaque black, since a zero value would be transparent."""
    if x.r == 0 and x.g == 0 and x.b == 0:
        return -0x1000000
    return Int32(
        UInt32(x.a) << 24 | UInt32(x.r) << 16 | UInt32(x.g) << 8 | UInt32(x.b)
    )


def rgba_from_int32(x: Int32) -> RGBA:
    """Unpacks an ARGB int32 into a colour (Go `rgbaFromInt32`)."""
    var u = UInt32(x)
    return RGBA(UInt8(u >> 16), UInt8(u >> 8), UInt8(u), UInt8(u >> 24))


def item_info[T: Item](it: T) -> ItemInfo:
    """Returns what a stack needs to know about an item (Go asks
    `MaxCounter` and `Durable` on every call).
    """
    var info = ItemInfo()
    info.air = it.encode_item().name == "minecraft:air"
    comptime if conforms_to(T, MaxCounter):
        info.max_count = _max_count(it)
    comptime if conforms_to(T, Durable):
        var d = _durability_info(it)
        info.max_durability = d.max_durability
        info.persistent = d.persistent
    comptime if conforms_to(T, Repairable):
        info.repairable = True
    return info


def _max_count[T: MaxCounter](it: T) -> Int:
    return it.max_count()


def _durability_info[T: Durable](it: T) -> DurabilityInfo:
    return it.durability_info()
