"""End-to-end check of a running Ignis server with two Mojo bots.

    mojo run -I src -I third_party/protocol/src -I third_party/nethernet/src \
        interop/bots/two_bots.mojo http://127.0.0.1:19160

Bot A joins, then bot B. Each must receive chunks (`LevelChunk`) and a
non-empty `SubChunk` for the bottom of its spawn column; B must be shown A
(`PlayerList` and `AddPlayer`). A then walks three blocks east with
`PlayerAuthInput` and B must receive the movement (`MoveActorAbsolute` for
A's runtime ID at the new position). A chats and B must receive the line
`<A> ...`. Finally B leaves and A must see it go (`RemoveActor` and a
`PlayerList` removal). Prints `PASS <check>` lines and fails on the first
check that does not hold.

    ... interop/bots/two_bots.mojo watch http://127.0.0.1:19160 SECONDS

joins as `Watcher` and prints `ADD <name> <id>`, `MOVE <id> x y z yaw` (at
most one per entity every half second), `CHAT <message>` and
`REMOVE <id>` lines for SECONDS seconds: a way to observe another client,
such as the vanilla one, move.

    ... interop/bots/two_bots.mojo walk http://127.0.0.1:19160 SECONDS

joins as `Walker` and paces in front of the spawn for another client to
watch.
"""

from minecraft.conn import Conn
from minecraft.dial import Dialer
from minecraft.protocol.block_pos import SubChunkPos
from minecraft.protocol.math import Vec3
from minecraft.protocol.packet.add_player import AddPlayer
from minecraft.protocol.packet.id import (
    ID_ADD_PLAYER,
    ID_LEVEL_CHUNK,
    ID_MOVE_ACTOR_ABSOLUTE,
    ID_PLAYER_LIST,
    ID_REMOVE_ACTOR,
    ID_SUB_CHUNK,
    ID_TEXT,
)
from minecraft.protocol.packet.move_actor_absolute import MoveActorAbsolute
from minecraft.protocol.packet.packet import PacketData
from minecraft.protocol.packet.player_auth_input import PlayerAuthInput
from minecraft.protocol.packet.player_list import PlayerList
from minecraft.protocol.packet.remove_actor import RemoveActor
from minecraft.protocol.packet.sub_chunk import SubChunk
from minecraft.protocol.packet.sub_chunk_request import SubChunkRequest
from minecraft.protocol.packet.text import TEXT_TYPE_CHAT, Text
from minecraft.protocol.player import (
    PLAYER_LIST_ACTION_ADD,
    PLAYER_LIST_ACTION_REMOVE,
)
from minecraft.protocol.sub_chunk import SUB_CHUNK_RESULT_SUCCESS
from minecraft.protocol.sub_chunk import SubChunkOffset
from nethernet.os.time import monotonic_ms
from std.collections import Dict
from std.sys import argv


struct Bot(Movable):
    """A joined bot and what it has seen so far."""

    var name: String
    var conn: Conn
    var chunks: Int
    var sub_chunk_ok: Bool
    var players: Dict[String, UInt64]
    var removed: List[Int64]
    var list_removed: Int
    var last_move: Optional[MoveActorAbsolute]
    var chat: List[String]

    def __init__(out self, address: String, name: String) raises:
        var dialer = Dialer()
        dialer.identity_data.display_name = name.copy()
        self.conn = dialer.dial(address)
        self.name = name.copy()
        self.chunks = 0
        self.sub_chunk_ok = False
        self.players = Dict[String, UInt64]()
        self.removed = List[Int64]()
        self.list_removed = 0
        self.last_move = None
        self.chat = List[String]()
        print("JOINED", name, self.conn.game_data.player_position)

    def handle(mut self, pk: PacketData) raises:
        var id = pk.id()
        var sid = self.conn.shield_id
        if id == ID_LEVEL_CHUNK:
            self.chunks += 1
        elif id == ID_SUB_CHUNK:
            var sc = pk.decode[SubChunk](sid, False)
            for ref e in sc.sub_chunk_entries:
                if e.result == SUB_CHUNK_RESULT_SUCCESS and e.raw_payload:
                    self.sub_chunk_ok = True
        elif id == ID_ADD_PLAYER:
            var ap = pk.decode[AddPlayer](sid, False)
            self.players[ap.username] = ap.entity_runtime_id
        elif id == ID_PLAYER_LIST:
            var pl = pk.decode[PlayerList](sid, False)
            for ref e in pl.entries:
                if e.action_type == PLAYER_LIST_ACTION_REMOVE:
                    self.list_removed += 1
        elif id == ID_MOVE_ACTOR_ABSOLUTE:
            self.last_move = pk.decode[MoveActorAbsolute](sid, False)
        elif id == ID_REMOVE_ACTOR:
            self.removed.append(
                pk.decode[RemoveActor](sid, False).entity_unique_id
            )
        elif id == ID_TEXT:
            self.chat.append(pk.decode[Text](sid, False).message)

    def pump(mut self, ms: Int) raises:
        var deadline = monotonic_ms() + ms
        while True:
            var left = deadline - monotonic_ms()
            if left <= 0:
                return
            var next = self.conn.read_packet(min(left, 10))
            if next:
                self.handle(next.value())

    def request_bottom_sub_chunk(mut self) raises:
        var req = SubChunkRequest()
        req.dimension = 0
        req.position = SubChunkPos()
        req.position.y = -4
        req.offsets.append(SubChunkOffset(0, 0, 0))
        self.conn.write_packet(req)

    def walk_to(mut self, x: Float32, eye_y: Float32, z: Float32) raises:
        var pk = PlayerAuthInput()
        pk.position = Vec3(x, eye_y, z)
        pk.yaw = 90
        pk.head_yaw = 90
        self.conn.write_packet(pk)

    def say(mut self, message: String) raises:
        var pk = Text()
        pk.text_type = TEXT_TYPE_CHAT
        pk.source_name = self.name.copy()
        pk.xuid = self.conn.identity_data.xuid.copy()
        pk.message = message.copy()
        self.conn.write_packet(pk)


def pump_both(mut a: Bot, mut b: Bot, ms: Int) raises:
    var deadline = monotonic_ms() + ms
    while monotonic_ms() < deadline:
        a.pump(5)
        b.pump(5)


def check(ok: Bool, name: String) raises:
    """Prints PASS or raises FAIL."""
    if not ok:
        raise Error(t"FAIL {name}")
    print("PASS", name)


comptime _SEES = 0
comptime _CHUNKS = 1
comptime _MOVE = 2
comptime _CHAT = 3


def _cond(a: Bot, b: Bot, what: Int) raises -> Bool:
    if what == _SEES:
        return _b_sees_a(a, b)
    if what == _CHUNKS:
        return _chunks_and_sub(a, b)
    if what == _MOVE:
        return _b_saw_move(a, b)
    return _b_saw_chat(a, b)


def wait_until(mut a: Bot, mut b: Bot, ms: Int, what: Int) raises -> Bool:
    var deadline = monotonic_ms() + ms
    while monotonic_ms() < deadline:
        if _cond(a, b, what):
            return True
        a.pump(5)
        b.pump(5)
    return _cond(a, b, what)


def _b_sees_a(a: Bot, b: Bot) raises -> Bool:
    return a.name in b.players


def _chunks_and_sub(a: Bot, b: Bot) raises -> Bool:
    return a.chunks >= 4 and b.chunks >= 4 and a.sub_chunk_ok and b.sub_chunk_ok


def _b_saw_move(a: Bot, b: Bot) raises -> Bool:
    if not b.last_move:
        return False
    ref mv = b.last_move.value()
    return (
        mv.entity_runtime_id == b.players[a.name]
        and abs(mv.position.x - 3.5) < 0.01
    )


def _b_saw_chat(a: Bot, b: Bot) raises -> Bool:
    for m in b.chat:
        if m == String(t"<{a.name}> hello from {a.name}"):
            return True
    return False


def _a_saw_b_leave(a: Bot, b: Bot) raises -> Bool:
    return len(a.removed) > 0 and a.list_removed > 0


def run_pair(address: String) raises:
    var a = Bot(address, "BotA")
    var b = Bot(address, "BotB")
    check(wait_until(a, b, 10000, _SEES), "B is shown A (AddPlayer)")
    # Sub-chunks are only served for columns already sent.
    a.pump(1000)
    b.pump(1000)
    a.request_bottom_sub_chunk()
    b.request_bottom_sub_chunk()
    check(
        wait_until(a, b, 15000, _CHUNKS),
        "both receive LevelChunk and a SubChunk with blocks",
    )
    print("CHUNKS", a.chunks, b.chunks)
    var spawn = a.conn.game_data.player_position
    for step in range(1, 7):
        a.walk_to(spawn.x + Float32(step) * 0.5, spawn.y, spawn.z)
        pump_both(a, b, 60)
    check(
        wait_until(a, b, 5000, _MOVE),
        "B sees A move to x=3.5 (MoveActorAbsolute)",
    )
    ref mv = b.last_move.value()
    print("MOVE", mv.entity_runtime_id, mv.position, mv.rotation)
    a.say("hello from BotA")
    check(wait_until(a, b, 5000, _CHAT), "B receives A's chat line")
    b.conn.close()
    var deadline = monotonic_ms() + 10000
    while monotonic_ms() < deadline and not _a_saw_b_leave(a, b):
        a.pump(10)
    check(_a_saw_b_leave(a, b), "A sees B leave (RemoveActor, PlayerList)")
    a.conn.close()
    print("DONE")


def watch(address: String, seconds: Int) raises:
    var w = Bot(address, "Watcher")
    var names = Dict[UInt64, String]()
    var last_print = Dict[UInt64, Int]()
    var seen_chat = 0
    var deadline = monotonic_ms() + seconds * 1000
    while monotonic_ms() < deadline:
        var next = w.conn.read_packet(50)
        if not next:
            continue
        var pk = next.take()
        w.handle(pk)
        if pk.id() == ID_ADD_PLAYER:
            var ap = pk.decode[AddPlayer](w.conn.shield_id, False)
            names[ap.entity_runtime_id] = ap.username
            print("ADD", ap.username, ap.entity_runtime_id, ap.position)
        elif pk.id() == ID_MOVE_ACTOR_ABSOLUTE:
            ref mv = w.last_move.value()
            var now = monotonic_ms()
            var last = last_print.get(mv.entity_runtime_id).or_else(0)
            if now - last >= 500:
                last_print[mv.entity_runtime_id] = now
                print(
                    "MOVE",
                    mv.entity_runtime_id,
                    mv.position.x,
                    mv.position.y,
                    mv.position.z,
                    mv.rotation.y,
                )
        elif pk.id() == ID_REMOVE_ACTOR:
            print("REMOVE", w.removed[len(w.removed) - 1])
        while seen_chat < len(w.chat):
            print("CHAT", w.chat[seen_chat])
            seen_chat += 1
    w.conn.close()


def walk(address: String, seconds: Int) raises:
    """Joins as `Walker` and paces between x=-3 and x=3 at z=4.5, five
    blocks in front of a player standing at spawn and facing south."""
    var w = Bot(address, "Walker")
    # Spawn is half a block above the grass; stand on it.
    var eye_y = w.conn.game_data.player_position.y - 1.5
    var x = Float32(-3)
    var dx = Float32(0.1)
    var deadline = monotonic_ms() + seconds * 1000
    var last = 0
    while monotonic_ms() < deadline:
        var pk = PlayerAuthInput()
        pk.position = Vec3(x, eye_y, 4.5)
        pk.yaw = 180
        pk.head_yaw = 180
        w.conn.write_packet(pk)
        w.pump(50)
        if monotonic_ms() - last > 1000:
            last = monotonic_ms()
            print("WALKER", x, eye_y, 4.5)
        x += dx
        if x > 3 or x < -3:
            dx = -dx
    w.conn.close()


def main() raises:
    var args = argv()
    if len(args) >= 2 and String(args[1]) == "walk":
        walk(String(args[2]), Int(String(args[3])))
        return
    if len(args) >= 2 and String(args[1]) == "watch":
        watch(String(args[2]), Int(String(args[3])))
        return
    run_pair(String(args[1]))
