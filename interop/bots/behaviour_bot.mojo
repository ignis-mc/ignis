"""A bot that watches world-driven block behaviour, for `scripts/e2e.sh`.
Prints `PASS <check>` lines and fails on the first check that does not
hold.

    behaviour_bot.mojo prepare WORLD_DIR
        writes a world with a water source next to spawn, whose first flow
        is a scheduled update saved with its chunk, and sand floating in
        the water's path.
    behaviour_bot.mojo watch ADDRESS
        joins the server serving that world and checks that the water
        flows (UpdateBlock with flowing water), the sand falls as a
        falling block entity (AddActor `minecraft:falling_block` with the
        sand as its variant) and lands in the water.
"""

from std.sys import argv

from minecraft.dial import Dialer
from minecraft.protocol.entity_metadata import ENTITY_DATA_KEY_VARIANT
from minecraft.protocol.packet.add_actor import AddActor
from minecraft.protocol.packet.id import ID_ADD_ACTOR, ID_UPDATE_BLOCK
from minecraft.protocol.packet.update_block import UpdateBlock
from nethernet.os.time import monotonic_ms

from ignis.block.cube.pos import Pos
from ignis.block.register import vanilla_block_registry
from ignis.block.sand import Sand
from ignis.block.water import Water
from ignis.server.conf import Config
from ignis.server.server import open_world

comptime _WATER = Pos(2, -60, 2)
comptime _SAND = Pos(4, -59, 2)
comptime _SAND_LANDS = Pos(4, -60, 2)


def check(ok: Bool, name: String) raises:
    if not ok:
        raise Error(t"FAIL {name}")
    print("PASS", name)


def prepare(folder: String) raises:
    var conf = Config()
    conf.world_folder = folder
    var w = open_world(conf, 0)
    var water = Water(still=True, depth=8)
    w.set_liquid(_WATER, water)
    # Neighbour updates are not saved; the scheduled update is.
    w.schedule_block_update(_WATER, water, 250)
    w.set_block(_SAND, Sand())
    w.close()
    print("PREPARED", folder)


def watch(address: String) raises:
    var br = vanilla_block_registry("resources/block_states.nbt")
    var sand = br.block_runtime_id(Sand())
    var d = Dialer()
    d.identity_data.display_name = "Watcher"
    var conn = d.dial(address)
    print("JOINED")
    var flowing = 0
    var falling = False
    var falling_variant = Int32(-1)
    var landed = False
    var deadline = monotonic_ms() + 8000
    while monotonic_ms() < deadline:
        var next = conn.read_packet(20)
        if not next:
            continue
        var pk = next.take()
        if pk.id() == ID_UPDATE_BLOCK:
            var u = pk.decode[UpdateBlock](conn.shield_id, False)
            var rid = u.new_block_runtime_id
            if case .Some(s) = br.runtime_id_to_state(rid):
                if s.name == "minecraft:flowing_water":
                    flowing += 1
            var p = Pos(Int(u.position.x), Int(u.position.y), Int(u.position.z))
            if p == _SAND_LANDS and rid == sand and u.layer == 0:
                landed = True
        elif pk.id() == ID_ADD_ACTOR:
            var a = pk.decode[AddActor](conn.shield_id, False)
            if a.entity_type == "minecraft:falling_block":
                falling = True
                if case .Some(v) = a.entity_metadata.get(
                    ENTITY_DATA_KEY_VARIANT
                ):
                    if v.isa[Int32]():
                        falling_variant = v[Int32]
        if flowing > 0 and falling and landed:
            break
    print("FLOWING_UPDATES", flowing)
    check(flowing > 0, "the water flows (UpdateBlock with flowing water)")
    check(falling, "the sand falls as a falling block (AddActor)")
    check(
        falling_variant == Int32(sand),
        "the falling block shows sand (variant = sand runtime ID)",
    )
    check(landed, "the sand lands where the water flowed (UpdateBlock)")
    conn.close()
    print("DONE")


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise Error("usage: behaviour_bot (prepare WORLD_DIR | watch ADDRESS)")
    var mode = String(args[1])
    if mode == "prepare":
        prepare(String(args[2]))
    elif mode == "watch":
        watch(String(args[2]))
    else:
        raise Error(t"unknown mode {mode}")
