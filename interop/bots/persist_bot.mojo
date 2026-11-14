"""A bot with a fixed identity for the persistence and command checks of
`scripts/e2e.sh`. Every mode joins as `Persist` (always the same UUID),
does one thing, prints `PASS <check>` lines and fails on the first check
that does not hold.

    persist_bot.mojo walk ADDRESS X Z
        walks to (X, spawn Y, Z) and leaves; the server saves its data.
    persist_bot.mojo expect-pos ADDRESS X Z
        checks that it joins at (X, Z), where it left.
    persist_bot.mojo expect-time ADDRESS MIN MAX
        checks that the world time in StartGame is in [MIN, MAX].
    persist_bot.mojo expect-start ADDRESS X Y Z MODE TIME
        checks the StartGame position (feet), game type and time, and that
        the sub-chunks of the spawn column hold blocks.
    persist_bot.mojo command ADDRESS EXPECT LINE...
        checks that AvailableCommands lists /gamemode, /tp, /time, /list and
        /say, sends LINE as a CommandRequest and checks that a
        CommandOutput message contains EXPECT.
"""

from minecraft.conn import Conn
from minecraft.dial import Dialer
from minecraft.protocol.math import Vec3
from minecraft.protocol.packet.available_commands import AvailableCommands
from minecraft.protocol.packet.command_output import CommandOutput
from minecraft.protocol.packet.command_request import CommandRequest
from minecraft.protocol.packet.id import (
    ID_AVAILABLE_COMMANDS,
    ID_COMMAND_OUTPUT,
    ID_TEXT,
)
from minecraft.protocol.block_pos import SubChunkPos
from minecraft.protocol.packet.id import ID_SUB_CHUNK
from minecraft.protocol.packet.player_auth_input import PlayerAuthInput
from minecraft.protocol.packet.sub_chunk import SubChunk
from minecraft.protocol.packet.sub_chunk_request import SubChunkRequest
from minecraft.protocol.sub_chunk import (
    SUB_CHUNK_RESULT_SUCCESS,
    SubChunkOffset,
)
from minecraft.protocol.packet.text import Text
from nethernet.os.time import monotonic_ms
from std.sys import argv

comptime _UUID = "5f0e3a52-8a7c-4d2e-9b61-3c2f1d0e9a77"


def check(ok: Bool, name: String) raises:
    """Prints PASS or raises FAIL."""
    if not ok:
        raise Error(t"FAIL {name}")
    print("PASS", name)


def join(address: String) raises -> Conn:
    var dialer = Dialer()
    dialer.identity_data.display_name = "Persist"
    dialer.identity_data.identity = _UUID
    var conn = dialer.dial(address)
    print(
        "JOINED",
        conn.game_data.player_position,
        "time",
        conn.game_data.time,
        "mode",
        conn.game_data.player_game_mode,
    )
    return conn^


def pump(mut conn: Conn, ms: Int) raises:
    var deadline = monotonic_ms() + ms
    while monotonic_ms() < deadline:
        _ = conn.read_packet(10)


def walk(address: String, x: Float32, z: Float32) raises:
    var conn = join(address)
    var spawn = conn.game_data.player_position
    pump(conn, 500)
    var steps = 10
    for i in range(1, steps + 1):
        var f = Float32(i) / Float32(steps)
        var pk = PlayerAuthInput()
        pk.position = Vec3(
            spawn.x + (x - spawn.x) * f, spawn.y, spawn.z + (z - spawn.z) * f
        )
        pk.yaw = 45
        pk.head_yaw = 45
        conn.write_packet(pk)
        pump(conn, 50)
    pump(conn, 500)
    conn.close()
    print("WALKED", x, z)


def expect_pos(address: String, x: Float32, z: Float32) raises:
    var conn = join(address)
    var p = conn.game_data.player_position
    check(
        abs(p.x - x) < 0.01 and abs(p.z - z) < 0.01,
        String(t"joins where it left ({x}, {z})"),
    )
    check(abs(conn.game_data.yaw - 45) < 0.01, "keeps its yaw")
    conn.close()


def expect_time(address: String, lo: Int, hi: Int) raises:
    var conn = join(address)
    var t = Int(conn.game_data.time)
    check(t >= lo and t <= hi, String(t"world time {t} in [{lo}, {hi}]"))
    conn.close()


def expect_start(
    address: String, x: Float32, y: Float32, z: Float32, mode: Int, time: Int
) raises:
    var conn = join(address)
    var p = conn.game_data.player_position
    check(
        abs(p.x - x) < 0.01
        and abs(p.y - 1.62 - y) < 0.01
        and abs(p.z - z) < 0.01,
        String(t"spawns at the level.dat spawn ({x}, {y}, {z})"),
    )
    check(
        Int(conn.game_data.player_game_mode) == mode,
        String(t"game type {mode} from level.dat"),
    )
    check(
        Int(conn.game_data.time) == time, String(t"time {time} from level.dat")
    )
    pump(conn, 1500)
    var cx = Int32(Int(x)) >> 4
    var cz = Int32(Int(z)) >> 4
    var req = SubChunkRequest()
    req.dimension = 0
    req.position = SubChunkPos()
    req.position.x = cx
    req.position.y = 0
    req.position.z = cz
    for dy in range(-4, 20):
        req.offsets.append(SubChunkOffset(0, Int8(dy), 0))
    conn.write_packet(req)
    var blocks = 0
    var deadline = monotonic_ms() + 10000
    var answered = False
    while monotonic_ms() < deadline and not answered:
        var next = conn.read_packet(10)
        if next and next.value().id() == ID_SUB_CHUNK:
            answered = True
            var sc = next.value().decode[SubChunk](conn.shield_id, False)
            for ref e in sc.sub_chunk_entries:
                if e.result != SUB_CHUNK_RESULT_SUCCESS or not e.raw_payload:
                    continue
                if len(e.raw_payload.value()) > 4:
                    blocks += 1
    print("SUBCHUNKS with blocks:", blocks)
    check(blocks > 0, "the spawn column has stored sub-chunks with blocks")
    conn.close()


def command(address: String, expect: String, line: String) raises:
    var conn = join(address)
    var deadline = monotonic_ms() + 10000
    var names = List[String]()
    while monotonic_ms() < deadline and len(names) == 0:
        var next = conn.read_packet(10)
        if next and next.value().id() == ID_AVAILABLE_COMMANDS:
            var ac = next.value().decode[AvailableCommands](
                conn.shield_id, False
            )
            for ref c in ac.commands:
                names.append(c.name)
    print("COMMANDS", len(names))
    for want in ["gamemode", "tp", "time", "list", "say"]:
        check(String(want) in names, String(t"AvailableCommands has /{want}"))
    var req = CommandRequest()
    req.command_line = line.copy()
    conn.write_packet(req)
    var found = False
    deadline = monotonic_ms() + 10000
    while monotonic_ms() < deadline and not found:
        var next = conn.read_packet(10)
        if not next:
            continue
        if next.value().id() == ID_COMMAND_OUTPUT:
            var out = next.value().decode[CommandOutput](conn.shield_id, False)
            for ref m in out.output_messages:
                var text = m.message.copy()
                for p in m.parameters:
                    text += " " + p
                print("OUTPUT", m.success, text)
                if expect in text:
                    found = True
        elif next.value().id() == ID_TEXT:
            var t = next.value().decode[Text](conn.shield_id, False)
            print("TEXT", t.message)
            if expect in t.message:
                found = True
    check(found, String(t"{line} answers {expect}"))
    pump(conn, 300)
    conn.close()


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise Error("usage: persist_bot.mojo MODE ADDRESS ...")
    var mode = String(args[1])
    var address = String(args[2])
    if mode == "walk":
        walk(address, Float32(atof(args[3])), Float32(atof(args[4])))
    elif mode == "expect-pos":
        expect_pos(address, Float32(atof(args[3])), Float32(atof(args[4])))
    elif mode == "expect-time":
        expect_time(address, Int(args[3]), Int(args[4]))
    elif mode == "expect-start":
        expect_start(
            address,
            Float32(atof(args[3])),
            Float32(atof(args[4])),
            Float32(atof(args[5])),
            Int(args[6]),
            Int(args[7]),
        )
    elif mode == "command":
        var line = String(args[4])
        for i in range(5, len(args)):
            line += " " + String(args[i])
        command(address, String(args[3]), line)
    else:
        raise Error(t"unknown mode {mode}")
