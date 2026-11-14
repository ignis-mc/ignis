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
    health_bot.mojo eat ADDRESS
        takes a golden apple from the creative inventory, goes back to
        survival and eats it: eating particles (ActorEvent feed), then
        absorption and regeneration (MobEffect), 4 absorption health and the
        apple gone from the hotbar.
    health_bot.mojo fight ADDRESS
        two bots: Fighter punches Victim (1 damage, knock-back), a second
        punch within the 500 ms immunity does nothing, Fighter shoots Victim
        with a bow from creative, then punches until Victim dies with
        `death.attack.player`.
"""

from std.collections import Dict
from std.sys import argv

from minecraft.conn import Conn
from minecraft.dial import Dialer
from minecraft.protocol.container import (
    CONTAINER_CREATED_OUTPUT,
    CONTAINER_HOT_BAR,
    FullContainerName,
)
from minecraft.protocol.inventory import (
    HAND_SLOT_MAIN_HAND,
    USE_ITEM_ACTION_CLICK_AIR,
    USE_ITEM_ON_ENTITY_ACTION_ATTACK,
    InventoryTransactionData,
    ReleaseItemTransactionData,
    UseItemOnEntityTransactionData,
    UseItemTransactionData,
)
from minecraft.protocol.item import ItemInstance
from minecraft.protocol.item_stack import (
    CraftCreativeStackRequestAction,
    ItemStackRequest as StackRequest,
    StackRequestAction,
    StackRequestSlotInfo,
    TakeStackRequestAction,
)
from minecraft.protocol.math import Vec3
from minecraft.protocol.packet.add_player import AddPlayer
from minecraft.protocol.packet.command_request import CommandRequest
from minecraft.protocol.packet.creative_content import CreativeContent
from minecraft.protocol.packet.inventory_slot import InventorySlot
from minecraft.protocol.packet.inventory_transaction import (
    InventoryTransaction,
)
from minecraft.protocol.packet.item_stack_request import ItemStackRequest
from minecraft.protocol.packet.item_stack_response import ItemStackResponse
from minecraft.protocol.packet.mob_effect import MOB_EFFECT_ADD, MobEffect
from minecraft.protocol.packet.actor_event import (
    ACTOR_EVENT_DEATH,
    ACTOR_EVENT_FEED,
    ACTOR_EVENT_HURT,
    ActorEvent,
)
from minecraft.protocol.packet.id import (
    ID_ACTOR_EVENT,
    ID_ADD_ACTOR,
    ID_ADD_PLAYER,
    ID_CREATIVE_CONTENT,
    ID_INVENTORY_SLOT,
    ID_ITEM_STACK_RESPONSE,
    ID_MOB_EFFECT,
    ID_RESPAWN,
    ID_SET_ACTOR_MOTION,
    ID_TEXT,
    ID_UPDATE_ATTRIBUTES,
)
from minecraft.protocol.packet.set_actor_motion import SetActorMotion
from minecraft.protocol.packet.add_actor import AddActor
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
    var absorption: Float32
    var feeds: Int
    var effects: List[Int32]
    var creative_items: List[Tuple[UInt32, Int32]]
    var held: ItemInstance
    var players: Dict[String, UInt64]
    var arrows: Int
    var hotbar_count: Int

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
        self.absorption = 0
        self.feeds = 0
        self.effects = List[Int32]()
        self.creative_items = List[Tuple[UInt32, Int32]]()
        self.held = ItemInstance()
        self.players = Dict[String, UInt64]()
        self.arrows = 0
        self.hotbar_count = -1
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
                elif a.name == "minecraft:absorption":
                    self.absorption = a.value
                elif a.name == "minecraft:player.hunger":
                    self.food = a.value
        elif id == ID_ACTOR_EVENT:
            var e = pk.decode[ActorEvent](sid, False)
            if e.event_type == ACTOR_EVENT_FEED:
                self.feeds += 1
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
        elif id == ID_MOB_EFFECT:
            var m = pk.decode[MobEffect](sid, False)
            if m.operation == MOB_EFFECT_ADD:
                self.effects.append(m.effect_type)
        elif id == ID_CREATIVE_CONTENT:
            var c = pk.decode[CreativeContent](sid, False)
            for ref it in c.items:
                self.creative_items.append(
                    (it.creative_item_network_id, it.item.item_type.network_id)
                )
        elif id == ID_INVENTORY_SLOT:
            var sl = pk.decode[InventorySlot](sid, False)
            if sl.window_id == 0 and sl.slot == 0:
                self.held = sl.new_item.copy()
        elif id == ID_ITEM_STACK_RESPONSE:
            var r = pk.decode[ItemStackResponse](sid, False)
            for ref resp in r.responses:
                for ref c in resp.container_info:
                    if c.container.container_id == CONTAINER_HOT_BAR:
                        for ref sl in c.slot_info:
                            if sl.slot == 0:
                                self.hotbar_count = Int(sl.count)
        elif id == ID_ADD_PLAYER:
            var a = pk.decode[AddPlayer](sid, False)
            self.players[a.username] = a.entity_runtime_id
        elif id == ID_ADD_ACTOR:
            var a = pk.decode[AddActor](sid, False)
            if a.entity_type == "minecraft:arrow":
                self.arrows += 1
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

    def command(mut self, line: String) raises:
        var req = CommandRequest()
        req.command_line = line
        self.conn.write_packet(req)
        self.pump(600)

    def creative_pick(mut self, name: String, count: Int) raises:
        """Takes `count` of an item from the creative inventory into hotbar
        slot 0 (the vanilla client's CraftCreative and Take)."""
        var network_id = Int32(-1)
        for ref e in self.conn.game_data.items:
            if e.name == name:
                network_id = Int32(e.runtime_id)
        var cid = UInt32(0)
        for e in self.creative_items:
            if e[1] == network_id:
                cid = e[0]
                break
        if cid == 0:
            raise Error(t"FAIL {name} is not in the creative inventory")
        var r = StackRequest()
        r.request_id = -9
        var craft = CraftCreativeStackRequestAction()
        craft.creative_item_network_id = cid
        craft.number_of_crafts = 1
        r.actions.append(StackRequestAction(craft^))
        var take = TakeStackRequestAction()
        take.count = UInt8(count)
        take.source = slot(CONTAINER_CREATED_OUTPUT, 50, -9)
        take.destination = slot(CONTAINER_HOT_BAR, 0, 0)
        r.actions.append(StackRequestAction(take^))
        var pk = ItemStackRequest()
        pk.requests.append(r^)
        self.conn.write_packet(pk)
        self.pump(800)

    def transaction(mut self, var data: InventoryTransactionData) raises:
        var tr = InventoryTransaction()
        tr.transaction_data = data^
        self.conn.write_packet(tr)

    def use_in_air(mut self) raises:
        var use = UseItemTransactionData()
        use.action_type = USE_ITEM_ACTION_CLICK_AIR
        use.hot_bar_slot = 0
        use.held_item = self.held.copy()
        use.position = self.eye
        self.transaction(InventoryTransactionData(use^))

    def release(mut self) raises:
        var rel = ReleaseItemTransactionData()
        rel.hot_bar_slot = 0
        rel.hand = HAND_SLOT_MAIN_HAND
        rel.held_item = self.held.copy()
        rel.head_position = self.eye
        self.transaction(InventoryTransactionData(rel^))

    def attack(mut self, target: UInt64) raises:
        var a = UseItemOnEntityTransactionData()
        a.target_entity_runtime_id = target
        a.action_type = USE_ITEM_ON_ENTITY_ACTION_ATTACK
        a.hot_bar_slot = 0
        a.hand = HAND_SLOT_MAIN_HAND
        a.held_item = self.held.copy()
        a.position = self.eye
        self.transaction(InventoryTransactionData(a^))

    def look(mut self, eye: Vec3, yaw: Float32, pitch: Float32) raises:
        var pk = PlayerAuthInput()
        pk.position = eye
        pk.yaw = yaw
        pk.head_yaw = yaw
        pk.pitch = pitch
        self.conn.write_packet(pk)
        self.eye = eye

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


def slot(container: UInt8, s: Int, id: Int32) -> StackRequestSlotInfo:
    var info = StackRequestSlotInfo()
    info.container = FullContainerName()
    info.container.container_id = container
    info.slot = UInt8(s)
    info.stack_network_id = id
    return info^


def eat(address: String) raises:
    var bot = Bot(address, "Eater")
    bot.input(Vec3(0.5, GROUND + EYE, 0.5))
    bot.pump(1500)
    bot.command("/gamemode creative")
    bot.creative_pick("minecraft:golden_apple", 1)
    check(bot.hotbar_count == 1, "a golden apple is in the hotbar")
    bot.command("/gamemode survival")
    bot.use_in_air()
    for _ in range(36):
        bot.idle(1)
    bot.use_in_air()
    bot.idle(10)
    print(
        "FEEDS",
        bot.feeds,
        "EFFECTS",
        len(bot.effects),
        "ABSORPTION",
        bot.absorption,
    )
    check(bot.feeds > 0, "eating shows particles (ActorEvent feed)")
    var absorption = False
    var regeneration = False
    for e in bot.effects:
        absorption = absorption or e == 22
        regeneration = regeneration or e == 10
    check(absorption, "the apple gives absorption (MobEffect 22)")
    check(regeneration, "the apple gives regeneration (MobEffect 10)")
    check(bot.absorption == 4, "4 absorption health (UpdateAttributes)")
    check(bot.held.stack.count == 0, "the apple is eaten")
    bot.conn.close()
    print("DONE")


comptime VICTIM_EYE = Vec3(3.5, GROUND + EYE, 0.5)
comptime FIGHTER_EYE = Vec3(0.5, GROUND + EYE, 0.5)


def both(mut victim: Bot, mut fighter: Bot, ticks: Int) raises:
    """Keeps both bots in place, the fighter facing +x, for `ticks`."""
    for _ in range(ticks):
        victim.input(VICTIM_EYE)
        fighter.look(FIGHTER_EYE, -90, 0)
        victim.pump(25)
        fighter.pump(25)


def fight(address: String) raises:
    var victim = Bot(address, "Victim")
    var fighter = Bot(address, "Fighter")

    both(victim, fighter, 50)
    check("Victim" in fighter.players, "Fighter sees Victim (AddPlayer)")
    var target = fighter.players["Victim"]
    fighter.attack(target)
    both(victim, fighter, 4)
    print(
        "HEALTH",
        victim.health,
        "HURTS",
        victim.hurts,
        "KNOCKED",
        victim.knocked,
    )
    check(victim.health == 19, "a punch deals 1 damage")
    check(victim.hurts == 1, "the victim sees its hurt animation")
    check(victim.knocked >= 1, "the punch knocks the victim back")
    fighter.attack(target)
    both(victim, fighter, 4)
    check(victim.hurts == 1, "a punch within 500 ms does not hurt")
    # A bow from creative: drawn for a second and released at the victim.
    fighter.command("/gamemode creative")
    fighter.creative_pick("minecraft:bow", 1)
    check(fighter.hotbar_count == 1, "Fighter holds a bow")
    var hurts = victim.hurts
    fighter.use_in_air()
    both(victim, fighter, 24)
    fighter.release()
    both(victim, fighter, 30)
    print("ARROWS", fighter.arrows, "HURTS", hurts, "->", victim.hurts)
    check(fighter.arrows >= 1, "the bow shoots an arrow (AddActor)")
    check(victim.hurts > hurts, "the arrow hurts the victim")
    fighter.creative_pick("minecraft:diamond_sword", 1)
    fighter.command("/gamemode survival")
    var deadline = monotonic_ms() + 20000
    while monotonic_ms() < deadline and victim.deaths == 0:
        fighter.attack(target)
        both(victim, fighter, 12)
    print("HEALTH", victim.health, "DEATHS", victim.deaths)
    check(victim.deaths == 1, "the diamond sword kills the victim")
    var message = False
    for m in victim.messages:
        if m == "death.attack.player":
            message = True
    check(message, "the death message death.attack.player")
    victim.conn.close()
    fighter.conn.close()
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
    elif mode == "eat":
        eat(String(args[2]))
    elif mode == "fight":
        fight(String(args[2]))
    else:
        raise Error(t"unknown mode {mode}")
