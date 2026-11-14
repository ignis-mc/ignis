from ignis.mgl64 import Vec3
from ignis.player.player import Player
from ignis.server.command import CommandSource, execute_command
from ignis.server.conf import Config
from ignis.server.server import Server, strip_formatting
from minecraft.protocol.uuid import UUID
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _server() raises -> Server:
    var conf = Config()
    conf.address = "127.0.0.1:0"
    return Server(conf^)


def test_unknown_command() raises:
    var srv = _server()
    var src = CommandSource(console_at=Vec3(0, 0, 0))
    execute_command(srv, src, "/nope a b")
    ref e = src.output.value().errors()[0]
    assert_equal(e.translation, "§r§c%commands.generic.unknown§r")
    assert_equal(e.params[0], "nope")


def test_player_lines_need_a_slash() raises:
    # Go's ExecuteCommand ignores a player's line without `/`; the console
    # may leave it out.
    var srv = _server()
    var p = Player("Steve", "", UUID(), Vec3(1, 2, 3))
    var src = CommandSource(p)
    assert_false(src.is_console())
    execute_command(srv, src, "time set 5")
    assert_false(Bool(src.output))
    var console = CommandSource(console_at=Vec3(0, 0, 0))
    execute_command(srv, console, "time set 5")
    assert_true(Bool(console.output))
    assert_equal(srv.world.time(), 5)


def test_arguments_split_at_single_spaces() raises:
    # `strings.Split(line, " ")`: two spaces leave an empty argument.
    var srv = _server()
    var src = CommandSource(console_at=Vec3(0, 0, 0))
    execute_command(srv, src, "time  set 5")
    assert_equal(src.output.value().message_count(), 0)


def test_sources() raises:
    var p = Player("Steve", "", UUID(), Vec3(1, 2, 3))
    var src = CommandSource(p)
    assert_true(src.target().player)
    assert_equal(src.target().name, "Steve")
    var console = CommandSource(console_at=Vec3(0, 0, 0))
    assert_false(console.target().player)
    assert_equal(console.name, "Server")


def test_strip_formatting() raises:
    assert_equal(strip_formatting("§r§cUnknown§r command"), "Unknown command")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
