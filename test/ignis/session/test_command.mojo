from std.collections import Set
from std.testing import TestSuite, assert_equal, assert_true

from ignis import cmd
from ignis.session.command import build_available_commands, command_output
from minecraft.protocol.command import CommandOrigin
from minecraft.protocol.packet.available_commands import AvailableCommands
from minecraft.protocol.packet.command_output import (
    COMMAND_OUTPUT_TYPE_ALL_OUTPUT,
)
from minecraft.protocol.reader import Reader
from minecraft.protocol.writer import Writer
from samples import TestSource, read_vectors, sample_registry


def _hex(b: List[UInt8]) -> String:
    comptime DIGITS = "0123456789abcdef"
    var out = String()
    for x in b:
        var hi = Int(x >> 4)
        var lo = Int(x & 0xF)
        out += String(DIGITS[byte = hi : hi + 1])
        out += String(DIGITS[byte = lo : lo + 1])
    return out^


def test_available_commands_match_dragonfly() raises:
    var r = sample_registry()
    var op = TestSource("Op", True)
    var user = TestSource("User", False)
    var packets = 0
    for row in read_vectors():
        if row[0] != "packet":
            continue
        # The subset of the registry Dragonfly built the packet from.
        var subset = Dict[String, cmd.Command[TestSource]]()
        for name in row[2].split(","):
            var c = r.by_alias(String(name)).value().copy()
            subset[c.name()] = c.copy()
            for a in c.aliases():
                subset[a] = c.copy()
        var soft = Set[String]()
        if row[3] == "true":
            soft.add("Item")
        var runnable = Dict[String, List[Int]]()
        var pk: AvailableCommands
        if row[1] == "Op":
            pk = build_available_commands(subset, op, soft, runnable)
        else:
            pk = build_available_commands(subset, user, soft, runnable)
        var w = Writer()
        pk.marshal(w)
        assert_equal(_hex(w.take()), row[4], row[1] + " " + row[2])
        packets += 1
    assert_equal(packets, 16)


def test_runnable_map() raises:
    var r = sample_registry()
    var runnable = Dict[String, List[Int]]()
    _ = build_available_commands(
        r.commands(), TestSource("User", False), Set[String](), runnable
    )
    assert_equal(len(runnable), 9)
    assert_true("secret" not in runnable)
    assert_equal(runnable["config"], [0, 1, 2])


def test_command_output_packet() raises:
    var o = cmd.Output()
    o.print("done")
    o.errort(cmd.MESSAGE_NUMBER_INVALID, "x")
    var origin = CommandOrigin()
    origin.request_id = "req"
    var pk = command_output(o, origin)
    assert_equal(pk.success_count, 1)
    assert_equal(pk.output_type, COMMAND_OUTPUT_TYPE_ALL_OUTPUT)
    assert_equal(pk.command_origin.request_id, "req")
    assert_equal(len(pk.output_messages), 2)
    assert_true(pk.output_messages[0].success)
    assert_equal(pk.output_messages[0].message, "done")
    assert_equal(len(pk.output_messages[0].parameters), 0)
    assert_true(not pk.output_messages[1].success)
    assert_equal(
        pk.output_messages[1].message, "§r§c> %commands.generic.num.invalid§r"
    )
    assert_equal(pk.output_messages[1].parameters, ["x"])
    # It encodes and decodes.
    var w = Writer()
    pk.marshal(w)
    var bytes = w.take()
    var back = type_of(pk)()
    var rd = Reader(bytes)
    back.marshal(rd)
    assert_equal(back.output_messages[1].parameters, ["x"])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
