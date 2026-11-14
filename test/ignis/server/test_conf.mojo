from ignis.server.conf import UserConfig, load_user_config
from ignis.world.game_mode import GAME_MODE_CREATIVE, GAME_MODE_SURVIVAL
from std.os import remove
from std.os.path import exists
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_defaults_round_trip() raises:
    var c = UserConfig()
    var back = UserConfig.from_toml(c.to_toml())
    assert_equal(back.network_address, "0.0.0.0:19132")
    assert_equal(back.server_name, "Ignis Server")
    assert_true(back.server_auth_enabled)
    assert_equal(back.players_maximum_chunk_radius, 32)
    var conf = back.config()
    assert_false(conf.auth_disabled)
    assert_true(conf.default_game_mode == GAME_MODE_SURVIVAL)


def test_dragonfly_style_file() raises:
    var c = UserConfig.from_toml(
        """[Network]
Address = "127.0.0.1:7560"
Transport = ["raknet", "nethernet"]
[Network.NetherNet]
KeyFile = "keys/server_identity_key.pem"
[Server]
Name = "Test"
AuthEnabled = false
DisableJoinQuitMessages = true
[World]
SaveData = true
GameMode = "creative"
[Players]
MaxCount = 5
MaximumChunkRadius = 8
[Resources]
Folder = "resources"
"""
    )
    var conf = c.config()
    assert_equal(conf.address, "127.0.0.1:7560")
    assert_equal(conf.name, "Test")
    assert_true(conf.auth_disabled)
    assert_false(conf.join_quit_messages)
    assert_true(conf.default_game_mode == GAME_MODE_CREATIVE)
    assert_equal(conf.max_players, 5)
    assert_equal(conf.max_chunk_radius, 8)


def test_save_data() raises:
    # Dragonfly's defaults keep both the world and the players on disk.
    var conf = UserConfig.from_toml(UserConfig().to_toml()).config()
    assert_equal(conf.world_folder.value(), "world")
    assert_equal(conf.players_folder.value(), "players")
    var c = UserConfig.from_toml(
        """[World]
SaveData = false
Folder = "w2"
[Players]
SaveData = true
Folder = "p2"
"""
    )
    conf = c.config()
    assert_false(Bool(conf.world_folder))
    assert_equal(conf.players_folder.value(), "p2")
    var back = UserConfig.from_toml(c.to_toml())
    assert_false(back.world_save_data)
    assert_equal(back.world_folder, "w2")


def test_raknet_only_rejected() raises:
    with assert_raises(contains="nethernet"):
        _ = UserConfig.from_toml('[Network]\nTransport = ["raknet"]\n')


def test_unknown_game_mode() raises:
    var c = UserConfig.from_toml('[World]\nGameMode = "hardcore"\n')
    with assert_raises(contains="game mode"):
        _ = c.config()


def test_load_writes_defaults() raises:
    var path = String("test_conf_config.toml")
    if exists(path):
        remove(path)
    var c = load_user_config(path)
    assert_true(exists(path))
    assert_equal(c.server_name, "Ignis Server")
    var again = load_user_config(path)
    assert_equal(again.network_address, c.network_address)
    remove(path)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
