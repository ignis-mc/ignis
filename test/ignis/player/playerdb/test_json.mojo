from ignis.mgl64 import Vec3
from ignis.player.player import Player
from ignis.player.playerdb.json import Data
from ignis.world.game_mode import GAME_MODE_CREATIVE
from ignis.block.cube.rotation import Rotation
from minecraft.protocol.uuid import UUID
from std.testing import TestSuite, assert_equal, assert_true

# What Dragonfly's json.Marshal(jsonData) writes for a player in creative at
# (1.5, -60, 2.25) facing yaw 90, pitch -10, with one item and an effect.
comptime GO_JSON = (
    '{"UUID":"6a5d3e2f-1c2b-4a3d-9e8f-0a1b2c3d4e5f","XUID":"2535","Username"'
    ':"Steve","Position":[1.5,-60,2.25],"Velocity":[0,-0.08,0],"Yaw":90,'
    '"Pitch":-10,"Health":17.5,"MaxHealth":20,"Hunger":18,"FoodTick":3,'
    '"ExhaustionLevel":0.5,"SaturationLevel":2,"EnchantmentSeed":'
    '-4223000000000000000,"Experience":7,"AirSupply":300,"MaxAirSupply":300,'
    '"GameMode":1,"Inventory":{"Items":[{"Item":"CgAAAA==","Slot":0}],'
    '"Boots":null,"Leggings":null,"Chestplate":null,"Helmet":null,'
    '"OffHand":null,"MainHandSlot":2},"EnderChestInventory":[],"Effects":[{'
    '"ID":1,"Level":2,"Duration":1000000000,"Ambient":false,'
    '"ParticlesHidden":false,"Infinite":false}],"FireTicks":0,'
    '"FallDistance":1.25,"Dimension":0}'
)


def test_decode_dragonfly() raises:
    var d = Data.from_json(GO_JSON.as_bytes())
    assert_equal(d.uuid, "6a5d3e2f-1c2b-4a3d-9e8f-0a1b2c3d4e5f")
    assert_equal(d.username, "Steve")
    assert_true(d.position == Vec3(1.5, -60, 2.25))
    assert_equal(d.yaw, 90)
    assert_equal(d.pitch, -10)
    assert_equal(d.health, 17.5)
    assert_equal(d.hunger, 18)
    assert_equal(d.enchantment_seed, -4223000000000000000)
    assert_true(d.mode().value() == GAME_MODE_CREATIVE)
    assert_equal(d.fall_distance, 1.25)


def test_round_trip_keeps_untracked_fields() raises:
    var d = Data.from_json(GO_JSON.as_bytes())
    var p = Player(
        "Alex", "99", UUID(), Vec3(3, 4, 5), GAME_MODE_CREATIVE, Rotation(1, 2)
    )
    d.put_player(p, 0)
    var back = Data.from_json(d.to_json().as_bytes())
    assert_equal(back.username, "Alex")
    assert_true(back.position == Vec3(3, 4, 5))
    assert_equal(back.yaw, 1)
    assert_equal(back.pitch, 2)
    # Fields Ignis does not track yet survive the round trip.
    assert_equal(back.health, 17.5)
    assert_equal(back.experience, 7)
    assert_equal(back.enchantment_seed, -4223000000000000000)


def test_defaults() raises:
    var d = Data()
    var back = Data.from_json(d.to_json().as_bytes())
    assert_equal(back.health, 20)
    assert_equal(back.hunger, 20)
    assert_equal(back.saturation_level, 5)
    assert_equal(back.air_supply, 300)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
