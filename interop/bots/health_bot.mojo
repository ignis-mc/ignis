"""A bot that gets hurt, dies and respawns, for `scripts/e2e.sh`. Prints
`PASS <check>` lines and fails on the first check that does not hold.

    health_bot.mojo fall ADDRESS
        joins in survival on the flat world, jumps 10 blocks up and falls
        back: the server must show the hurt animation and send 13 health
        (Dragonfly: ceil(distance - 3) = 7 fall damage). Then it falls 30
        blocks: health 0, the death animation, the death message
        `death.attack.fall`, and after asking to respawn, a Respawn packet
        and full health again.
    health_bot.mojo prepare WORLD_DIR
        writes a world with an arrow flying at the spawn and lit TNT two
        blocks from it.
    health_bot.mojo hazards ADDRESS
        joins that world and stands at the spawn: the arrow hurts and
        knocks it back (SetActorMotion), then the explosion kills it with
        `death.attack.explosion`.
"""

from std.sys import argv

from minecraft.conn import Conn
from minecraft.dial import Dialer
from minecraft.protocol.math import Vec3
from minecraft.protocol.packet.actor_event import (
    ACTOR_EVENT_DEATH,
    ACTOR_EVENT_HURT,
    ActorEvent,
)
from minecraft.protocol.packet.id import (
    ID_ACTOR_EVENT,
    ID_RESPAWN,
    ID_SET_ACTOR_MOTION,
    ID_TEXT,
    ID_UPDATE_ATTRIBUTES,
)
from minecraft.protocol.packet.set_actor_motion import SetActorMotion
from minecraft.protocol.packet.packet import PacketData
from minecraft.protocol.packet.player_auth_input import PlayerAuthInput
from minecraft.protocol.packet.respawn import (
    RESPAWN_STATE_CLIENT_READY_TO_SPAWN,
    RESPAWN_STATE_READY_TO_SPAWN,
    Respawn,
)
from minecraft.protocol.packet.text import Text
from minecraft.protocol.packet.update_attributes import UpdateAttributes
from nethernet.os.time import monotonic_ms

from ignis.entity.arrow import Arrow
from ignis.entity.register import VanillaEntities
from ignis.entity.tnt import TNT
from ignis.mgl64 import Vec3 as Vec3d
from ignis.server.conf import Config
from ignis.server.server import open_world
from ignis.world.entity import EntityHandle, EntitySpawnOpts

comptime EYE = Float32(1.62)
comptime GROUND = Float32(-60)
"""The feet on the flat world's grass."""


def check(ok: Bool, name: String) raises:
    """Prints PASS or raises FAIL."""
    if not ok:
        raise Error(t"FAIL {name}")
    print("PASS", name)


struct Bot(Movable):
    var conn: Conn
    var eye: Vec3
    var health: Float32
    var food: Float32
    var hurts: Int
    var deaths: Int
    var messages: List[String]
    var respawned: Optional[Respawn]
    var knocked: Int

    def __init__(out self, address: String, name: String) raises:
        var d = Dialer()
        d.identity_data.display_name = name.copy()
        self.conn = d.dial(address)
        self.eye = self.conn.game_data.player_position
        self.health = -1
        self.food = -1
        self.hurts = 0
        self.deaths = 0
        self.messages = List[String]()
        self.respawned = None
        self.knocked = 0
        print("JOINED", name, self.eye)

    def handle(mut self, pk: PacketData) raises:
        var sid = self.conn.shield_id
        var id = pk.id()
        if id == ID_UPDATE_ATTRIBUTES:
            var u = pk.decode[UpdateAttributes](sid, False)
            if u.entity_runtime_id != 1:
                return
            for ref a in u.attributes:
                if a.name == "minecraft:health":
                    self.health = a.value
                elif a.name == "minecraft:player.hunger":
                    self.food = a.value
        elif id == ID_ACTOR_EVENT:
            var e = pk.decode[ActorEvent](sid, False)
            if e.entity_runtime_id != 1:
                return
            if e.event_type == ACTOR_EVENT_HURT:
                self.hurts += 1
            elif e.event_type == ACTOR_EVENT_DEATH:
                self.deaths += 1
        elif id == ID_TEXT:
            self.messages.append(pk.decode[Text](sid, False).message)
        elif id == ID_RESPAWN:
            self.respawned = pk.decode[Respawn](sid, False)
        elif id == ID_SET_ACTOR_MOTION:
            var m = pk.decode[SetActorMotion](sid, False)
            if m.entity_runtime_id == 1 and m.velocity.x > 0:
                self.knocked += 1

    def pump(mut self, ms: Int) raises:
        var deadline = monotonic_ms() + ms
        while monotonic_ms() < deadline:
            var next = self.conn.read_packet(10)
            if next:
                self.handle(next.value())

    def input(mut self, eye: Vec3) raises:
        """Sends one PlayerAuthInput with the eyes at `eye`."""
        var pk = PlayerAuthInput()
        pk.position = eye
        self.conn.write_packet(pk)
        self.eye = eye

    def idle(mut self, ticks: Int) raises:
        for _ in range(ticks):
            var here = self.eye
            self.input(here)
            self.pump(50)

    def fall_from(mut self, height: Float32) raises:
        """Goes `height` blocks above the ground and falls back half a
        block per tick."""
        var y = GROUND + height
        self.input(Vec3(self.eye.x, y + EYE, self.eye.z))
        self.pump(100)
        while y > GROUND:
            y = max(y - 0.5, GROUND)
            self.input(Vec3(self.eye.x, y + EYE, self.eye.z))
            self.pump(50)
        self.idle(4)


def fall(address: String) raises:
    var bot = Bot(address, "Faller")
    bot.input(Vec3(bot.eye.x, GROUND + EYE, bot.eye.z))
    bot.pump(1500)
    check(bot.health == 20, "full health on joining (UpdateAttributes 20)")
    check(bot.food == 20, "full food on joining")
    bot.fall_from(10)
    print("HEALTH", bot.health, "HURTS", bot.hurts)
    check(bot.hurts >= 1, "the fall shows the hurt animation (ActorEvent)")
    check(bot.health == 13, "a 10 block fall deals 7 damage")
    bot.fall_from(30)
    print("HEALTH", bot.health, "DEATHS", bot.deaths)
    check(bot.health == 0, "a 30 block fall kills (health 0)")
    check(bot.deaths == 1, "the death animation is shown (ActorEvent)")
    var message = False
    for m in bot.messages:
        if m == "death.attack.fall":
            message = True
    check(message, "the death message death.attack.fall")
    bot.pump(1200)
    var req = Respawn()
    req.state = RESPAWN_STATE_CLIENT_READY_TO_SPAWN
    req.entity_runtime_id = 1
    bot.conn.write_packet(req)
    bot.pump(1000)
    check(Bool(bot.respawned), "the server sends Respawn")
    var r = bot.respawned.value().copy()
    check(r.state == RESPAWN_STATE_READY_TO_SPAWN, "Respawn is ReadyToSpawn")
    print("RESPAWN AT", r.position, "HEALTH", bot.health)
    check(bot.health == 20, "respawning restores health")
    bot.conn.close()
    print("DONE")


def prepare(folder: String) raises:
    var conf = Config()
    conf.world_folder = folder
    var w = open_world(conf, 0)
    var a = EntitySpawnOpts()
    a.position = Vec3d(-20, -59.5, 0.5)
    a.velocity = Vec3d(2.5, 0.35, 0)
    _ = w.add_entity(
        EntityHandle[VanillaEntities](a, VanillaEntities.wrap(Arrow()))
    )
    var t = EntitySpawnOpts()
    t.position = Vec3d(2.5, -60, 0.5)
    _ = w.add_entity(
        EntityHandle[VanillaEntities](t, VanillaEntities.wrap(TNT(4000)))
    )
    w.close()
    print("PREPARED", folder)


def hazards(address: String) raises:
    var bot = Bot(address, "Target")
    var deadline = monotonic_ms() + 3000
    while monotonic_ms() < deadline and bot.hurts == 0:
        bot.input(Vec3(0.5, GROUND + EYE, 0.5))
        bot.pump(50)
    print("HEALTH", bot.health, "HURTS", bot.hurts, "KNOCKED", bot.knocked)
    check(bot.hurts >= 1, "the arrow hurts the player (ActorEvent hurt)")
    check(bot.health < 20, "the arrow takes health")
    check(bot.knocked >= 1, "the arrow knocks the player back (SetActorMotion)")
    deadline = monotonic_ms() + 6000
    while monotonic_ms() < deadline and bot.deaths == 0:
        bot.input(Vec3(0.5, GROUND + EYE, 0.5))
        bot.pump(50)
    print("HEALTH", bot.health, "DEATHS", bot.deaths)
    check(bot.deaths == 1, "the TNT explosion kills the player")
    var message = False
    for m in bot.messages:
        if m == "death.attack.explosion":
            message = True
    check(message, "the death message death.attack.explosion")
    bot.conn.close()
    print("DONE")


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise Error("usage: health_bot fall ADDRESS")
    var mode = String(args[1])
    if mode == "fall":
        fall(String(args[2]))
    elif mode == "prepare":
        prepare(String(args[2]))
    elif mode == "hazards":
        hazards(String(args[2]))
    else:
        raise Error(t"unknown mode {mode}")
