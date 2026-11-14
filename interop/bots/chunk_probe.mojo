"""Joins a server and prints the chunk data it sends for the column at the
spawn chunk, to compare Ignis with Dragonfly byte for byte.

    mojo run -I src -I third_party/protocol/src -I third_party/nethernet/src \
        interop/bots/chunk_probe.mojo http://127.0.0.1:19160 [name]

Prints `LEVEL_CHUNK x z dim count limit payload=<hex>` for the first
`LevelChunk` at (0, 0), then requests sub-chunks y -4..19 of that column
and prints `SUB y result hmtype payload=<hex>` per entry.
"""

from minecraft.dial import Dialer
from minecraft.protocol.block_pos import SubChunkPos
from minecraft.protocol.packet.id import ID_LEVEL_CHUNK, ID_SUB_CHUNK
from minecraft.protocol.packet.level_chunk import LevelChunk
from minecraft.protocol.packet.sub_chunk import SubChunk
from minecraft.protocol.packet.sub_chunk_request import SubChunkRequest
from minecraft.protocol.sub_chunk import SubChunkOffset
from nethernet.os.time import monotonic_ms
from nethernet.wire import hex_encode
from std.sys import argv


def main() raises:
    var args = argv()
    var dialer = Dialer()
    dialer.identity_data.display_name = (
        String(args[2]) if len(args) > 2 else "Probe"
    )
    var conn = dialer.dial(String(args[1]))
    print("SPAWNED", conn.game_data.player_position)
    var deadline = monotonic_ms() + 15000
    var got = False
    while not got and monotonic_ms() < deadline:
        var next = conn.read_packet(deadline - monotonic_ms())
        if not next:
            break
        var pk = next.take()
        if pk.id() != ID_LEVEL_CHUNK:
            continue
        var lc = pk.decode[LevelChunk](conn.shield_id, False)
        if lc.position.x != 0 or lc.position.z != 0:
            continue
        var limit = Int32(-1)
        if lc.sub_chunk_limit:
            limit = lc.sub_chunk_limit.value()
        print(
            "LEVEL_CHUNK",
            lc.position.x,
            lc.position.z,
            lc.dimension,
            lc.sub_chunk_count,
            limit,
            String(t"payload={hex_encode(Span(lc.raw_payload))}"),
        )
        got = True
    var req = SubChunkRequest()
    req.dimension = 0
    req.position = SubChunkPos()
    for y in range(-4, 20):
        req.offsets.append(SubChunkOffset(0, Int8(y), 0))
    conn.write_packet(req)
    deadline = monotonic_ms() + 10000
    while monotonic_ms() < deadline:
        var next = conn.read_packet(deadline - monotonic_ms())
        if not next:
            break
        var pk = next.take()
        if pk.id() != ID_SUB_CHUNK:
            continue
        var sc = pk.decode[SubChunk](conn.shield_id, False)
        for ref e in sc.sub_chunk_entries:
            var payload = String("-")
            if e.raw_payload:
                payload = hex_encode(Span(e.raw_payload.value()))
            print(
                "SUB",
                e.offset.y,
                e.result,
                e.height_map_type,
                String(t"payload={payload}"),
            )
        break
    conn.close()
