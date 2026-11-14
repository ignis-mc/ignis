"""Player data as JSON, ported from Dragonfly
`server/player/playerdb/json.go` (`jsonData`, `toJson`, `fromJson`).

The JSON has Go's field names, so a database written by Dragonfly loads
here and the other way round. Inventory items are kept as their encoded
NBT (Go's `[]byte`, base64 in JSON); `playerdb.inventory` converts them to
and from stacks. Ignis has no effects or health yet: those fields keep the
values that were loaded (or Dragonfly's defaults for a new player), and
effects are written as `null`, which Dragonfly reads as empty.
"""

from std.math import isfinite

from nethernet.crypto.base64 import base64_decode, base64_encode
from nethernet.json import json_quote

from ...block.cube.rotation import Rotation
from ...entity.effect import Effect
from ...entity.effect.register import VanillaEffects
from ...internal.json import JSON_ARRAY, JSON_NUMBER, JSON_STRING, JsonDoc
from ...mgl64 import Vec3
from ...world.game_mode import GameMode, game_mode_by_id
from ..living import Living
from ..player import Player


@fieldwise_init
struct Slot(Copyable):
    """One stored inventory slot (Go `jsonSlot`)."""

    var item: List[UInt8]
    """The item as little-endian NBT (Go `Item`)."""
    var slot: Int
    """The slot index (Go `Slot`)."""


struct Data(Copyable, Defaultable):
    """The stored data of a player (Go `jsonData`)."""

    var uuid: String
    """Go `UUID`."""
    var xuid: String
    """Go `XUID`."""
    var username: String
    """Go `Username`."""
    var position: Vec3
    """Go `Position`."""
    var velocity: Vec3
    """Go `Velocity`."""
    var yaw: Float64
    """Go `Yaw`."""
    var pitch: Float64
    """Go `Pitch`."""
    var health: Float64
    """Go `Health`."""
    var max_health: Float64
    """Go `MaxHealth`."""
    var hunger: Int
    """Go `Hunger`."""
    var food_tick: Int
    """Go `FoodTick`."""
    var exhaustion_level: Float64
    """Go `ExhaustionLevel`."""
    var saturation_level: Float64
    """Go `SaturationLevel`."""
    var enchantment_seed: Int64
    """Go `EnchantmentSeed`."""
    var experience: Int
    """Go `Experience`."""
    var air_supply: Int
    """Go `AirSupply`."""
    var max_air_supply: Int
    """Go `MaxAirSupply`."""
    var game_mode: UInt8
    """Go `GameMode`."""
    var fire_ticks: Int64
    """Go `FireTicks`."""
    var fall_distance: Float64
    """Go `FallDistance`."""
    var dimension: Int32
    """Go `Dimension`."""
    var items: List[Slot]
    """Go `Inventory.Items`: the non-empty main inventory slots."""
    var boots: List[UInt8]
    """Go `Inventory.Boots`; empty for none."""
    var leggings: List[UInt8]
    """Go `Inventory.Leggings`."""
    var chestplate: List[UInt8]
    """Go `Inventory.Chestplate`."""
    var helmet: List[UInt8]
    """Go `Inventory.Helmet`."""
    var off_hand: List[UInt8]
    """Go `Inventory.OffHand`."""
    var main_hand_slot: UInt32
    """Go `Inventory.MainHandSlot`."""
    var ender_chest: List[Slot]
    """Go `EnderChestInventory`."""
    var effects: List[Effect]
    """Go `Effects`."""

    def __init__(out self):
        """Creates the data of a new player with Dragonfly's defaults."""
        self.uuid = String()
        self.xuid = String()
        self.username = String()
        self.position = Vec3()
        self.velocity = Vec3()
        self.yaw = 0
        self.pitch = 0
        self.health = 20
        self.max_health = 20
        self.hunger = 20
        self.food_tick = 0
        self.exhaustion_level = 0
        self.saturation_level = 5
        self.enchantment_seed = 0
        self.experience = 0
        self.air_supply = 300
        self.max_air_supply = 300
        self.game_mode = 0
        self.fire_ticks = 0
        self.fall_distance = 0
        self.dimension = 0
        self.items = List[Slot]()
        self.boots = List[UInt8]()
        self.leggings = List[UInt8]()
        self.chestplate = List[UInt8]()
        self.helmet = List[UInt8]()
        self.off_hand = List[UInt8]()
        self.main_hand_slot = 0
        self.ender_chest = List[Slot]()
        self.effects = List[Effect]()

    def put_player(mut self, p: Player, dimension: Int):
        """Updates the fields Ignis tracks from a player (Go `toJson` over
        `Player.Data`)."""
        self.uuid = String(p.uuid())
        self.xuid = p.xuid()
        self.username = p.name()
        self.position = p.position()
        self.yaw = p.rotation().yaw()
        self.pitch = p.rotation().pitch()
        self.game_mode = UInt8(p.game_mode().id)
        self.dimension = Int32(dimension)
        ref l = p.living
        self.health = l.health.health
        self.max_health = l.health.max
        self.hunger = l.hunger.food_level
        self.food_tick = l.hunger.food_tick
        self.exhaustion_level = l.hunger.exhaustion_level
        self.saturation_level = l.hunger.saturation_level
        self.experience = l.experience.experience
        self.air_supply = l.air_supply_ticks
        self.max_air_supply = l.max_air_supply_ticks
        self.fire_ticks = Int64(l.fire_ticks)
        self.fall_distance = l.fall_distance
        self.effects = l.effects.copy()

    def apply_living(self, mut l: Living):
        """Restores the survival state (Go `Config.Apply`): the values as
        saved, effects without their `Start`."""
        l.health.health = self.health
        l.health.max = self.max_health
        l.hunger.food_level = self.hunger
        l.hunger.food_tick = self.food_tick
        l.hunger.exhaustion_level = self.exhaustion_level
        l.hunger.saturation_level = self.saturation_level
        l.experience.reset()
        _ = l.experience.add(self.experience)
        l.air_supply_ticks = self.air_supply
        l.max_air_supply_ticks = self.max_air_supply
        l.fire_ticks = Int(self.fire_ticks)
        l.fall_distance = self.fall_distance
        l.effects = self.effects.copy()

    def rotation(self) -> Rotation:
        """Returns the yaw and pitch as a rotation."""
        return Rotation(self.yaw, self.pitch)

    def mode(self) -> Optional[GameMode]:
        """Returns the game mode, or None for an unknown ID (Go
        `GameModeByID`)."""
        return game_mode_by_id(Int(self.game_mode))

    def to_json(self) -> String:
        """Encodes the data as Dragonfly's `json.Marshal(jsonData)` does,
        floats aside (Go writes `20` where this writes `20.0`)."""
        var s = String("{")
        s += String(t'"UUID":{json_quote(self.uuid)}')
        s += String(t',"XUID":{json_quote(self.xuid)}')
        s += String(t',"Username":{json_quote(self.username)}')
        s += String(t',"Position":{_vec(self.position)}')
        s += String(t',"Velocity":{_vec(self.velocity)}')
        s += String(t',"Yaw":{_f(self.yaw)},"Pitch":{_f(self.pitch)}')
        s += String(t',"Health":{_f(self.health)}')
        s += String(t',"MaxHealth":{_f(self.max_health)}')
        s += String(t',"Hunger":{self.hunger},"FoodTick":{self.food_tick}')
        s += String(t',"ExhaustionLevel":{_f(self.exhaustion_level)}')
        s += String(t',"SaturationLevel":{_f(self.saturation_level)}')
        s += String(t',"EnchantmentSeed":{self.enchantment_seed}')
        s += String(t',"Experience":{self.experience}')
        s += String(t',"AirSupply":{self.air_supply}')
        s += String(t',"MaxAirSupply":{self.max_air_supply}')
        s += String(t',"GameMode":{self.game_mode}')
        s += ',"Inventory":{"Items":' + _slots(self.items)
        s += ',"Boots":' + _bytes(self.boots)
        s += ',"Leggings":' + _bytes(self.leggings)
        s += ',"Chestplate":' + _bytes(self.chestplate)
        s += ',"Helmet":' + _bytes(self.helmet)
        s += ',"OffHand":' + _bytes(self.off_hand)
        s += String(t',"MainHandSlot":{self.main_hand_slot}}}')
        s += ',"EnderChestInventory":' + _slots(self.ender_chest)
        s += ',"Effects":' + _effects(self.effects)
        s += String(t',"FireTicks":{self.fire_ticks}')
        s += String(t',"FallDistance":{_f(self.fall_distance)}')
        s += String(t',"Dimension":{self.dimension}')
        s += "}"
        return s^

    @staticmethod
    def from_json(text: Span[mut=False, UInt8, _]) raises -> Data:
        """Decodes data written by `to_json` or Dragonfly (Go
        `json.Unmarshal`); missing fields keep their zero values, as in Go.
        """
        var doc = JsonDoc(text)
        var r = doc.root()
        var d = Data()
        # Go unmarshals into a zero jsonData.
        d.health = 0
        d.max_health = 0
        d.hunger = 0
        d.saturation_level = 0
        d.air_supply = 0
        d.max_air_supply = 0
        if case .Some(i) = doc.get(r, "UUID"):
            d.uuid = doc.as_string(i)
        if case .Some(i) = doc.get(r, "XUID"):
            d.xuid = doc.as_string(i)
        if case .Some(i) = doc.get(r, "Username"):
            d.username = doc.as_string(i)
        d.position = _get_vec(doc, r, "Position")
        d.velocity = _get_vec(doc, r, "Velocity")
        d.yaw = _get_f(doc, r, "Yaw")
        d.pitch = _get_f(doc, r, "Pitch")
        d.health = _get_f(doc, r, "Health")
        d.max_health = _get_f(doc, r, "MaxHealth")
        d.hunger = _get_i(doc, r, "Hunger")
        d.food_tick = _get_i(doc, r, "FoodTick")
        d.exhaustion_level = _get_f(doc, r, "ExhaustionLevel")
        d.saturation_level = _get_f(doc, r, "SaturationLevel")
        d.enchantment_seed = Int64(_get_i(doc, r, "EnchantmentSeed"))
        d.experience = _get_i(doc, r, "Experience")
        d.air_supply = _get_i(doc, r, "AirSupply")
        d.max_air_supply = _get_i(doc, r, "MaxAirSupply")
        d.game_mode = UInt8(_get_i(doc, r, "GameMode"))
        d.fire_ticks = Int64(_get_i(doc, r, "FireTicks"))
        d.fall_distance = _get_f(doc, r, "FallDistance")
        d.dimension = Int32(_get_i(doc, r, "Dimension"))
        if case .Some(inv) = doc.get(r, "Inventory"):
            d.items = _get_slots(doc, inv, "Items")
            d.boots = _get_bytes(doc, inv, "Boots")
            d.leggings = _get_bytes(doc, inv, "Leggings")
            d.chestplate = _get_bytes(doc, inv, "Chestplate")
            d.helmet = _get_bytes(doc, inv, "Helmet")
            d.off_hand = _get_bytes(doc, inv, "OffHand")
            d.main_hand_slot = UInt32(_get_i(doc, inv, "MainHandSlot"))
        d.ender_chest = _get_slots(doc, r, "EnderChestInventory")
        if case .Some(arr) = doc.get(r, "Effects"):
            if doc.kind(arr) == JSON_ARRAY:
                for e in doc.children(arr):
                    var eff = VanillaEffects.from_data(
                        _get_i(doc, e, "ID"),
                        _get_i(doc, e, "Level"),
                        _get_i(doc, e, "Duration"),
                        _get_b(doc, e, "Ambient"),
                        _get_b(doc, e, "ParticlesHidden"),
                        _get_b(doc, e, "Infinite"),
                    )
                    if case .Some(x) = eff:
                        d.effects.append(x)
        return d^


def _effects(effects: List[Effect]) -> String:
    # Go `effectsToData`; an empty list is written as `[]` (Go writes `[]`
    # for the empty slice it makes).
    var s = String("[")
    for i in range(len(effects)):
        ref e = effects[i]
        if i > 0:
            s += ","
        s += String(t'{{"ID":{e.type_id()},"Level":{e.level()}')
        s += String(t',"Duration":{e.duration()}')
        s += String(t',"Ambient":{_bool(e.ambient())}')
        s += String(t',"ParticlesHidden":{_bool(e.particles_hidden())}')
        s += String(t',"Infinite":{_bool(e.infinite())}}}')
    s += "]"
    return s^


def _bool(b: Bool) -> String:
    return "true" if b else "false"


def _get_b(doc: JsonDoc, obj: Int, key: StringSlice) raises -> Bool:
    if case .Some(i) = doc.get(obj, key):
        return doc.as_bool(i)
    return False


def _f(v: Float64) -> String:
    # Go's encoder rejects NaN and infinities; store 0 rather than fail.
    if not isfinite(v):
        return "0"
    return String(v)


def _bytes(b: List[UInt8]) -> String:
    # Go's json.Marshal of a []byte: base64, null when nil.
    if len(b) == 0:
        return "null"
    return '"' + base64_encode(Span(b)) + '"'


def _slots(slots: List[Slot]) -> String:
    var s = String("[")
    for i in range(len(slots)):
        if i > 0:
            s += ","
        s += '{"Item":' + _bytes(slots[i].item)
        s += String(t',"Slot":{slots[i].slot}}}')
    return s + "]"


def _get_bytes(doc: JsonDoc, obj: Int, key: StringSlice) raises -> List[UInt8]:
    if case .Some(i) = doc.get(obj, key):
        if doc.kind(i) == JSON_STRING:
            return base64_decode(doc.as_string(i))
    return List[UInt8]()


def _get_slots(doc: JsonDoc, obj: Int, key: StringSlice) raises -> List[Slot]:
    var out = List[Slot]()
    if case .Some(arr) = doc.get(obj, key):
        if doc.kind(arr) == JSON_ARRAY:
            for e in doc.children(arr):
                out.append(
                    Slot(_get_bytes(doc, e, "Item"), _get_i(doc, e, "Slot"))
                )
    return out^


def _vec(v: Vec3) -> String:
    return String(t"[{_f(v.x())},{_f(v.y())},{_f(v.z())}]")


def _get_f(doc: JsonDoc, obj: Int, key: StringSlice) raises -> Float64:
    if case .Some(i) = doc.get(obj, key):
        if doc.kind(i) == JSON_NUMBER:
            return doc.as_float(i)
    return 0


def _get_i(doc: JsonDoc, obj: Int, key: StringSlice) raises -> Int:
    if case .Some(i) = doc.get(obj, key):
        if doc.kind(i) == JSON_NUMBER:
            return doc.as_int(i)
    return 0


def _get_vec(doc: JsonDoc, obj: Int, key: StringSlice) raises -> Vec3:
    if case .Some(i) = doc.get(obj, key):
        var c = doc.children(i)
        if len(c) == 3:
            return Vec3(
                doc.as_float(c[0]), doc.as_float(c[1]), doc.as_float(c[2])
            )
    return Vec3()
