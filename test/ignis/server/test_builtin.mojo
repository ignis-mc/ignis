from ignis.server.command import CommandSource, execute_command
from ignis.server.conf import Config
from ignis.server.server import Server
from ignis.mgl64 import Vec3
from std.testing import TestSuite, assert_equal, assert_true


def _server() raises -> Server:
    var conf = Config()
    conf.address = "127.0.0.1:0"
    return Server(conf^)


def _run(mut srv: Server, line: String) -> CommandSource:
    var src = CommandSource(console_at=Vec3(0, 0, 0))
    execute_command(srv, src, line)
    return src^


def _first(src: CommandSource) -> String:
    ref o = src.output.value()
    if o.message_count() > 0:
        return String(o.messages()[0])
    return String(o.errors()[0])


def test_time() raises:
    var srv = _server()
    var src = _run(srv, "time set 1234")
    assert_equal(_first(src), "Set the time to 1234")
    assert_equal(srv.world.time(), 1234)
    src = _run(srv, "/time set night")
    assert_equal(_first(src), "Set the time to 13000")
    _ = _run(srv, "time add 1000")
    assert_equal(srv.world.time(), 14000)
    src = _run(srv, "time query daytime")
    assert_equal(_first(src), "Time is 14000")


def test_list_and_registry() raises:
    var srv = _server()
    var src = _run(srv, "list")
    assert_equal(_first(src), "There are 0/1 players online:")
    for name in ["gamemode", "tp", "teleport", "time", "list", "say"]:
        assert_true(Bool(srv.commands.by_alias(String(name))), name)


def test_console_needs_a_player() raises:
    var srv = _server()
    var src = _run(srv, "gamemode creative")
    assert_equal(
        _first(src), "A player must be specified when running from the console"
    )
    src = _run(srv, "tp 1 2 3")
    assert_equal(
        _first(src), "A player must be specified when running from the console"
    )
    # A name that is not online.
    src = _run(srv, "gamemode creative Steve")
    var found = False
    for e in src.output.value().errors():
        found = found or "player.notFound" in e.translation
    assert_true(found)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
