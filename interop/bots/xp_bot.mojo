"""A bot that spends experience levels, for `scripts/e2e.sh`. Prints
`PASS <check>` lines and fails on the first check that does not hold.

    xp_bot.mojo prepare WORLD_DIR PLAYERS_DIR
        writes a flat world with an enchanting table, an anvil, a brewing
        stand holding a water bottle and blaze powder, a cake and a beacon
        on a one-layer iron pyramid giving Speed, and the data of the bot's
        player: survival, 30 levels, 10 hunger, a book, lapis lazuli,
        shears and nether wart.
    xp_bot.mojo run ADDRESS
        joins as that player: the beacon gives it Speed, eating the cake
        restores 2 hunger, enchanting the book takes 1 level and a lapis,
        renaming the shears on the anvil takes 1 level, and nether wart
        turns the water bottle into an awkward potion.
"""

from std.collections import Dict
from std.memory import ArcPointer
from std.sys import argv

from minecraft.conn import Conn
from minecraft.dial import Dialer
from minecraft.protocol.block_pos import BlockPos
from minecraft.protocol.container import (
    CONTAINER_ANVIL_INPUT,
    CONTAINER_BREWING_STAND_INPUT,
    CONTAINER_CREATED_OUTPUT,
    CONTAINER_ENCHANTING_INPUT,
    CONTAINER_ENCHANTING_MATERIAL,
    CONTAINER_HOT_BAR,
    CONTAINER_INVENTORY,
    CONTAINER_TYPE_ANVIL,
    CONTAINER_TYPE_BREWING_STAND,
    CONTAINER_TYPE_ENCHANTMENT,
    FullContainerName,
)
from minecraft.protocol.inventory import (
    USE_ITEM_ACTION_CLICK_BLOCK,
    InventoryTransactionData,
    UseItemTransactionData,
)
from minecraft.protocol.item import ItemInstance
from minecraft.protocol.item_stack import (
    ITEM_STACK_RESPONSE_STATUS_OK,
    CraftRecipeOptionalStackRequestAction,
    CraftRecipeStackRequestAction,
    ItemStackRequest as StackRequest,
    PlaceStackRequestAction,
    StackRequestAction,
    StackRequestSlotInfo,
    TakeStackRequestAction,
)
from minecraft.protocol.math import Vec3
from minecraft.protocol.packet.container_close import ContainerClose
from minecraft.protocol.packet.container_open import ContainerOpen
from minecraft.protocol.packet.container_set_data import ContainerSetData
from minecraft.protocol.packet.id import (
    ID_CONTAINER_CLOSE,
    ID_CONTAINER_OPEN,
    ID_CONTAINER_SET_DATA,
    ID_INVENTORY_CONTENT,
    ID_INVENTORY_SLOT,
    ID_ITEM_STACK_RESPONSE,
    ID_MOB_EFFECT,
    ID_PLAYER_ENCHANT_OPTIONS,
    ID_UPDATE_ATTRIBUTES,
)
from minecraft.protocol.packet.inventory_content import InventoryContent
from minecraft.protocol.packet.inventory_slot import InventorySlot
from minecraft.protocol.packet.inventory_transaction import (
    InventoryTransaction,
)
from minecraft.protocol.packet.item_stack_request import ItemStackRequest
from minecraft.protocol.packet.item_stack_response import ItemStackResponse
from minecraft.protocol.packet.mob_effect import MOB_EFFECT_ADD, MobEffect
from minecraft.protocol.packet.packet import PacketData
from minecraft.protocol.packet.player_auth_input import PlayerAuthInput
from minecraft.protocol.packet.player_enchant_options import (
    PlayerEnchantOptions,
)
from minecraft.protocol.packet.update_attributes import UpdateAttributes
from minecraft.protocol.uuid import UUID
from nethernet.os.time import monotonic_ms

from ignis.block.anvil import Anvil
from ignis.block.beacon import Beacon
from ignis.block.brewing_stand import BrewingStand
from ignis.block.cake import Cake
from ignis.block.cube.pos import Pos
from ignis.block.enchanting_table import EnchantingTable
from ignis.block.iron import Iron
from ignis.block.nether_wart import NetherWart
from ignis.item.blaze_powder import BlazePowder
from ignis.item.book import Book
from ignis.item.lapis_lazuli import LapisLazuli
from ignis.item.potion import Potion
from ignis.item.potion.potion import Potion as PotionType
from ignis.item.register import vanilla_item_registry
from ignis.item.shears import Shears
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3 as Vec3d
from ignis.player.playerdb.inventory import encode_item
from ignis.player.playerdb.json import Data, Slot
from ignis.player.playerdb.leveldb import Provider as PlayerProvider
from ignis.server.conf import Config
from ignis.server.server import open_world

comptime _UUID = "7c1d2e3f-4a5b-4c6d-8e7f-90a1b2c3d4e5"
"""The bot's fixed identity, so the prepared player data is its own."""
comptime FACE_UP = 1
comptime TABLE = (2, -60, 0)
comptime ANVIL = (0, -60, 2)
comptime STAND = (-2, -60, 0)
comptime CAKE = (0, -60, -2)
comptime BEACON = (6, -60, 6)
comptime LEVEL_30 = 1395
"""Experience points for level 30 (Go `experienceForLevels`)."""


def check(ok: Bool, name: String) raises:
    """Prints PASS or raises FAIL."""
    if not ok:
        raise Error(t"FAIL {name}")
    print("PASS", name)


def _key(container: UInt8, slot: Int) -> Int:
    return Int(container) * 256 + slot


def _pos(p: Tuple[Int, Int, Int]) -> Pos:
    return Pos(p[0], p[1], p[2])


def prepare(world: String, players: String) raises:
    var conf = Config()
    conf.world_folder = world
    # Containers need the item registry to save their items.
    var items = ArcPointer(vanilla_item_registry(conf.vanilla_items_path))
    var w = open_world(conf, 0, items)
    w.set_block(_pos(TABLE), EnchantingTable())
    w.set_block(_pos(ANVIL), Anvil())
    w.set_block(_pos(CAKE), Cake())
    w.set_block(_pos(STAND), BrewingStand())
    var inv = w.inventory(_pos(STAND)).value().copy()
    inv.set_item(1, Stack(Potion(type=PotionType.WATER), 1))
    inv.set_item(4, Stack(BlazePowder(), 1))
    w.set_inventory(_pos(STAND), inv^)
    var b = _pos(BEACON)
    for x in range(-1, 2):
        for z in range(-1, 2):
            w.set_block(Pos(b.x() + x, b.y() - 1, b.z() + z), Iron())
    var beacon = Beacon(level=1)
    beacon.primary = 1
    w.set_block(b, beacon)
    var br = w.block_registry()
    w.close()
    if w.last_error:
        raise Error(t"FAIL saving the world: {w.last_error.value()}")

    var d = Data()
    d.uuid = _UUID
    d.username = "Enchanter"
    d.position = Vec3d(0.5, -60, 0.5)
    d.game_mode = 0
    d.experience = LEVEL_30
    d.hunger = 10
    var stacks = [
        Stack(Book(), 1),
        Stack(LapisLazuli(), 3),
        Stack(Shears(), 1),
        Stack(NetherWart(), 1),
    ]
    for i in range(len(stacks)):
        d.items.append(Slot(encode_item(br[], items[], stacks[i]), i))
    var db = PlayerProvider(players)
    db.save(UUID.parse(_UUID), d)
    print("PREPARED", world, players)


struct Bot(Movable):
    var conn: Conn
    var eye: Vec3
    var names: Dict[Int32, String]
    var ok: Optional[Bool]
    var ids: Dict[Int, Int32]
    var counts: Dict[Int, Int]
    var nbts: Dict[Int, List[UInt8]]
    var window: Optional[Tuple[UInt8, UInt8]]
    var window_slots: Dict[Int, Tuple[Int32, Int, String, UInt32]]
    var closed: Bool
    var data: Dict[Int32, Int32]
    var next_request: Int32
    var level: Float32
    var hunger: Float32
    var effects: List[Int32]
    var offers: Optional[PlayerEnchantOptions]

    def __init__(out self, address: String) raises:
        var d = Dialer()
        d.identity_data.display_name = "Enchanter"
        d.identity_data.identity = _UUID
        self.conn = d.dial(address)
        self.eye = self.conn.game_data.player_position
        self.names = Dict[Int32, String]()
        for ref e in self.conn.game_data.items:
            self.names[Int32(e.runtime_id)] = e.name.copy()
        self.ok = None
        self.ids = Dict[Int, Int32]()
        self.counts = Dict[Int, Int]()
        self.nbts = Dict[Int, List[UInt8]]()
        self.window = None
        self.window_slots = Dict[Int, Tuple[Int32, Int, String, UInt32]]()
        self.closed = False
        self.data = Dict[Int32, Int32]()
        self.next_request = -1
        self.level = -1
        self.hunger = -1
        self.effects = List[Int32]()
        self.offers = None
        print("JOINED", self.eye)

    def handle(mut self, pk: PacketData) raises:
        var sid = self.conn.shield_id
        var id = pk.id()
        if id == ID_UPDATE_ATTRIBUTES:
            var u = pk.decode[UpdateAttributes](sid, False)
            for ref a in u.attributes:
                if a.name == "minecraft:player.level":
                    self.level = a.value
                elif a.name == "minecraft:player.hunger":
                    self.hunger = a.value
        elif id == ID_MOB_EFFECT:
            var m = pk.decode[MobEffect](sid, False)
            if m.operation == MOB_EFFECT_ADD:
                self.effects.append(m.effect_type)
        elif id == ID_PLAYER_ENCHANT_OPTIONS:
            self.offers = pk.decode[PlayerEnchantOptions](sid, False)
        elif id == ID_ITEM_STACK_RESPONSE:
            var r = pk.decode[ItemStackResponse](sid, False)
            for ref resp in r.responses:
                self.ok = resp.status == ITEM_STACK_RESPONSE_STATUS_OK
                for ref c in resp.container_info:
                    for ref s in c.slot_info:
                        var k = _key(c.container.container_id, Int(s.slot))
                        self.ids[k] = s.stack_network_id
                        self.counts[k] = Int(s.count)
        elif id == ID_CONTAINER_OPEN:
            var o = pk.decode[ContainerOpen](sid, False)
            self.window = (o.window_id, o.container_type)
            self.window_slots.clear()
            self.closed = False
        elif id == ID_CONTAINER_CLOSE:
            self.closed = True
        elif id == ID_INVENTORY_CONTENT:
            var c = pk.decode[InventoryContent](sid, False)
            if self.window and c.window_id == UInt32(self.window.value()[0]):
                for i in range(len(c.content)):
                    self._window_slot(i, c.content[i])
            elif c.window_id == 0:
                for i in range(len(c.content)):
                    self._inventory_slot(i, c.content[i])
        elif id == ID_INVENTORY_SLOT:
            var s = pk.decode[InventorySlot](sid, False)
            if self.window and s.window_id == UInt32(self.window.value()[0]):
                self._window_slot(Int(s.slot), s.new_item)
            elif s.window_id == 0:
                self._inventory_slot(Int(s.slot), s.new_item)
        elif id == ID_CONTAINER_SET_DATA:
            var d = pk.decode[ContainerSetData](sid, False)
            self.data[d.key] = d.value

    def _inventory_slot(mut self, i: Int, it: ItemInstance):
        var k = _key(CONTAINER_HOT_BAR if i < 9 else CONTAINER_INVENTORY, i)
        self.ids[k] = it.stack_network_id
        self.counts[k] = Int(it.stack.count)
        self.nbts[k] = it.stack.nbt_data.raw.copy()

    def _window_slot(mut self, slot: Int, it: ItemInstance):
        var name = String()
        if it.stack.item_type.network_id != 0:
            name = self.names.get(it.stack.item_type.network_id).or_else("")
        self.window_slots[slot] = (
            it.stack_network_id,
            Int(it.stack.count),
            name^,
            it.stack.item_type.metadata_value,
        )

    def pump(mut self, ms: Int) raises:
        var deadline = monotonic_ms() + ms
        while monotonic_ms() < deadline:
            var next = self.conn.read_packet(10)
            if next:
                self.handle(next.value())

    def idle(mut self, ms: Int) raises:
        """Sends an input every tick for `ms`, standing still."""
        var deadline = monotonic_ms() + ms
        while monotonic_ms() < deadline:
            var pk = PlayerAuthInput()
            pk.position = self.eye
            self.conn.write_packet(pk)
            self.pump(50)

    def id_of(self, container: UInt8, slot: Int) -> Int32:
        """Returns the stack network ID the server last gave a slot."""
        return self.ids.get(_key(container, slot)).or_else(0)

    def request(
        mut self,
        var actions: List[StackRequestAction],
        filters: List[String] = [],
    ) raises -> Bool:
        """Sends one request and waits for its response."""
        var r = StackRequest()
        r.request_id = self.next_request
        self.next_request -= 2
        for ref a in actions:
            r.actions.append(a.copy())
        r.filter_strings = filters.copy()
        var pk = ItemStackRequest()
        pk.requests.append(r^)
        self.ok = None
        self.conn.write_packet(pk)
        var deadline = monotonic_ms() + 2000
        while not self.ok and monotonic_ms() < deadline:
            self.pump(20)
        return Bool(self.ok) and self.ok.value()

    def move(
        mut self, src_c: UInt8, src: Int, dst_c: UInt8, dst: Int, count: Int
    ) raises -> Bool:
        """Places `count` items from one slot into another."""
        var p = PlaceStackRequestAction()
        p.count = UInt8(count)
        p.source = slot(src_c, src, self.id_of(src_c, src))
        p.destination = slot(dst_c, dst, self.id_of(dst_c, dst))
        return self.request([StackRequestAction(p^)])

    def take_result(
        mut self,
        var craft: StackRequestAction,
        hotbar: Int,
        filters: List[String] = [],
    ) raises -> Bool:
        """Sends a craft and takes its result into a hotbar slot."""
        var req = self.next_request
        var take = TakeStackRequestAction()
        take.count = 1
        take.source = slot(CONTAINER_CREATED_OUTPUT, 50, req)
        take.destination = slot(CONTAINER_HOT_BAR, hotbar, 0)
        return self.request([craft^, StackRequestAction(take^)], filters)

    def click(mut self, p: Tuple[Int, Int, Int]) raises:
        """Uses the held item on the top face of a block (UseItem)."""
        var use = UseItemTransactionData()
        use.action_type = USE_ITEM_ACTION_CLICK_BLOCK
        use.block_position = block_pos(p[0], p[1], p[2])
        use.block_face = FACE_UP
        use.hot_bar_slot = 0
        use.position = self.eye
        var tr = InventoryTransaction()
        tr.transaction_data = InventoryTransactionData(use^)
        self.conn.write_packet(tr)

    def open(mut self, p: Tuple[Int, Int, Int], kind: UInt8) raises -> Bool:
        self.window = None
        self.click(p)
        var deadline = monotonic_ms() + 2000
        while not self.window and monotonic_ms() < deadline:
            self.idle(50)
        self.idle(300)
        return Bool(self.window) and self.window.value()[1] == kind

    def close_window(mut self) raises:
        if not self.window:
            return
        var c = ContainerClose()
        c.window_id = self.window.value()[0]
        c.container_type = self.window.value()[1]
        self.closed = False
        self.conn.write_packet(c)
        var deadline = monotonic_ms() + 2000
        while not self.closed and monotonic_ms() < deadline:
            self.pump(20)
        self.window = None


def _contains(data: List[UInt8], text: StringSlice) -> Bool:
    var b = text.as_bytes()
    for i in range(len(data) - len(b) + 1):
        var hit = True
        for j in range(len(b)):
            if data[i + j] != b[j]:
                hit = False
                break
        if hit:
            return True
    return False


def slot(container: UInt8, s: Int, id: Int32) -> StackRequestSlotInfo:
    var info = StackRequestSlotInfo()
    info.container = FullContainerName()
    info.container.container_id = container
    info.slot = UInt8(s)
    info.stack_network_id = id
    return info^


def block_pos(x: Int, y: Int, z: Int) -> BlockPos:
    var b = BlockPos()
    b.x = Int32(x)
    b.y = Int32(y)
    b.z = Int32(z)
    return b^


def run(address: String) raises:
    var bot = Bot(address)
    bot.idle(1500)
    print("LEVEL", bot.level, "HUNGER", bot.hunger)
    check(bot.level == 30, "the saved player has 30 levels")
    check(bot.hunger == 10, "the saved player has 10 hunger")

    # The beacon broadcasts every 4 s.
    var deadline = monotonic_ms() + 6000
    while monotonic_ms() < deadline and 1 not in bot.effects:
        bot.idle(100)
    check(1 in bot.effects, "the beacon gives Speed (MobEffect 1)")

    bot.click(CAKE)
    bot.idle(500)
    print("HUNGER", bot.hunger)
    check(bot.hunger == 12, "a bite of cake restores 2 hunger")

    check(
        bot.open(TABLE, CONTAINER_TYPE_ENCHANTMENT),
        "the enchanting table opens",
    )
    check(
        bot.move(CONTAINER_HOT_BAR, 0, CONTAINER_ENCHANTING_INPUT, 14, 1),
        "the book goes on the table",
    )
    bot.idle(300)
    check(
        Bool(bot.offers) and len(bot.offers.value().options) == 3,
        "three enchantment offers (PlayerEnchantOptions)",
    )
    check(
        bot.move(CONTAINER_HOT_BAR, 1, CONTAINER_ENCHANTING_MATERIAL, 15, 3),
        "lapis lazuli goes on the table",
    )
    var craft = CraftRecipeStackRequestAction()
    craft.recipe_network_id = bot.offers.value().options[0].recipe_network_id
    craft.number_of_crafts = 1
    check(
        bot.take_result(StackRequestAction(craft^), 0),
        "enchanting with the first offer is accepted",
    )
    bot.idle(300)
    print("LEVEL", bot.level)
    check(bot.level == 29, "the first offer takes 1 level")
    check(
        bot.counts.get(_key(CONTAINER_ENCHANTING_MATERIAL, 15)).or_else(-1)
        == 2,
        "the first offer takes 1 lapis lazuli",
    )
    check(
        bot.counts.get(_key(CONTAINER_HOT_BAR, 0)).or_else(0) == 1,
        "the enchanted book lands in the hotbar",
    )
    bot.close_window()

    check(bot.open(ANVIL, CONTAINER_TYPE_ANVIL), "the anvil opens")
    check(
        bot.move(CONTAINER_HOT_BAR, 2, CONTAINER_ANVIL_INPUT, 1, 1),
        "the shears go on the anvil",
    )
    var rename = CraftRecipeOptionalStackRequestAction()
    rename.filter_string_index = 0
    check(
        bot.take_result(StackRequestAction(rename^), 2, ["Snips"]),
        "renaming the shears is accepted",
    )
    bot.idle(300)
    print("LEVEL", bot.level)
    check(bot.level == 28, "the rename takes 1 level")
    bot.close_window()

    check(
        bot.open(STAND, CONTAINER_TYPE_BREWING_STAND),
        "the brewing stand opens",
    )
    # Go's stack responses leave the name out (the client knows it); the
    # inventory the server resends after the click has it in the NBT.
    var nbt = bot.nbts.get(_key(CONTAINER_HOT_BAR, 2)).or_else([])
    check(_contains(nbt, "Snips"), "the shears are named Snips (item NBT)")
    var water = bot.window_slots.get(1)
    check(
        Bool(water) and water.value()[2] == "minecraft:potion",
        "the stand holds a water bottle",
    )
    check(
        bot.move(CONTAINER_HOT_BAR, 3, CONTAINER_BREWING_STAND_INPUT, 0, 1),
        "nether wart goes in",
    )
    # Go: a brew takes 20 s.
    deadline = monotonic_ms() + 25000
    while monotonic_ms() < deadline:
        bot.idle(500)
        var s = bot.window_slots.get(1)
        if s and s.value()[3] == 4:
            break
    check(len(bot.data) > 0, "the stand shows its progress (ContainerSetData)")
    var out = bot.window_slots.get(1)
    check(
        Bool(out)
        and out.value()[2] == "minecraft:potion"
        and out.value()[3] == 4,
        "the water bottle becomes an awkward potion",
    )
    var wart = bot.window_slots.get(0)
    check(not wart or wart.value()[1] == 0, "the nether wart is used up")
    bot.close_window()
    bot.conn.close()
    print("DONE")


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise Error("usage: xp_bot prepare WORLD PLAYERS | run ADDRESS")
    var mode = String(args[1])
    if mode == "prepare":
        prepare(String(args[2]), String(args[3]))
    elif mode == "run":
        run(String(args[2]))
    else:
        raise Error(t"unknown mode {mode}")
