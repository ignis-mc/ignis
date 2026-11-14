"""A bot that watches world entities, for `scripts/e2e.sh`. Prints
`PASS <check>` lines and fails on the first check that does not hold.

    entity_bot.mojo prepare WORLD_DIR
        writes a world with lit TNT and a flying arrow saved next to spawn.
    entity_bot.mojo watch ADDRESS
        joins the server serving that world and checks that the arrow flies
        (AddActor, then movement) and that the TNT explodes (AddActor, blocks
        around it turn to air, the TNT is removed).
"""

from std.sys import argv

from minecraft.dial import Dialer
from minecraft.protocol.packet.add_actor import AddActor
from minecraft.protocol.packet.id import (
    ID_ADD_ACTOR,
    ID_MOVE_ACTOR_ABSOLUTE,
    ID_REMOVE_ACTOR,
    ID_UPDATE_BLOCK,
)
from minecraft.protocol.packet.move_actor_absolute import MoveActorAbsolute
from minecraft.protocol.packet.remove_actor import RemoveActor
from minecraft.protocol.packet.update_block import UpdateBlock
from nethernet.os.time import monotonic_ms

from ignis.block.register import vanilla_block_registry
from ignis.entity.arrow import Arrow
from ignis.entity.register import VanillaEntities
from ignis.entity.tnt import TNT
from ignis.mgl64 import Vec3
from ignis.server.conf import Config
from ignis.server.server import open_world
from ignis.world.entity import EntityHandle, EntitySpawnOpts


def check(ok: Bool, name: String) raises:
    if not ok:
        raise Error(t"FAIL {name}")
    print("PASS", name)


def prepare(folder: String) raises:
    var conf = Config()
    conf.world_folder = folder
    var w = open_world(conf, 0)
    var opts = EntitySpawnOpts()
    opts.position = Vec3(6.5, -60, 6.5)
    _ = w.add_entity(
        EntityHandle[VanillaEntities](opts, VanillaEntities.wrap(TNT(3000)))
    )
    var a = EntitySpawnOpts()
    a.position = Vec3(-4.5, -58, 0.5)
    a.velocity = Vec3(-1.2, 0.3, 0.1)
    _ = w.add_entity(
        EntityHandle[VanillaEntities](a, VanillaEntities.wrap(Arrow()))
    )
    w.close()
    print("PREPARED", folder)


def watch(address: String) raises:
    var br = vanilla_block_registry("resources/block_states.nbt")
    var air = br.air_runtime_id()
    var d = Dialer()
    d.identity_data.display_name = "EntityWatcher"
    var conn = d.dial(address)
    print("JOINED")
    var tnt: Optional[UInt64] = None
    var arrow: Optional[UInt64] = None
    var arrow_moves = 0
    var air_updates = 0
    var tnt_removed = False
    var deadline = monotonic_ms() + 12000
    while monotonic_ms() < deadline:
        var next = conn.read_packet(20)
        if not next:
            continue
        var pk = next.take()
        var id = pk.id()
        if id == ID_ADD_ACTOR:
            var a = pk.decode[AddActor](conn.shield_id, False)
            if a.entity_type == "minecraft:tnt":
                tnt = a.entity_runtime_id
            elif a.entity_type == "minecraft:arrow":
                arrow = a.entity_runtime_id
        elif id == ID_MOVE_ACTOR_ABSOLUTE:
            var m = pk.decode[MoveActorAbsolute](conn.shield_id, False)
            if arrow and m.entity_runtime_id == arrow.value():
                arrow_moves += 1
        elif id == ID_UPDATE_BLOCK:
            var u = pk.decode[UpdateBlock](conn.shield_id, False)
            if u.new_block_runtime_id == air and u.layer == 0:
                air_updates += 1
        elif id == ID_REMOVE_ACTOR:
            var r = pk.decode[RemoveActor](conn.shield_id, False)
            if tnt and UInt64(r.entity_unique_id) == tnt.value():
                tnt_removed = True
        if tnt_removed and arrow_moves > 2 and air_updates > 0:
            break
    print("ARROW_MOVES", arrow_moves, "AIR_UPDATES", air_updates)
    check(Bool(arrow), "the arrow is shown (AddActor minecraft:arrow)")
    check(arrow_moves > 2, "the arrow flies (MoveActorAbsolute)")
    check(Bool(tnt), "the TNT is shown (AddActor minecraft:tnt)")
    check(air_updates > 0, "the explosion breaks blocks (UpdateBlock air)")
    check(tnt_removed, "the TNT is gone after exploding (RemoveActor)")
    conn.close()
    print("DONE")


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise Error("usage: entity_bot (prepare WORLD_DIR | watch ADDRESS)")
    var mode = String(args[1])
    if mode == "prepare":
        prepare(String(args[2]))
    elif mode == "watch":
        watch(String(args[2]))
    else:
        raise Error(t"unknown mode {mode}")
