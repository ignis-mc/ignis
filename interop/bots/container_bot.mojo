"""A bot that uses containers and crafts, for `scripts/e2e.sh`. Prints
`PASS <check>` lines and fails on the first check that does not hold.

    container_bot.mojo ADDRESS X Y Z

In creative (to take items with `CraftCreative`), on the ground block at X
Y Z and two blocks east of it: places a chest and a furnace, opens the
chest and moves logs in and out of it, opens it again to find them kept,
crafts planks in the 2x2 grid and a crafting table from them, and smelts
raw iron with coal in the furnace, taking the iron ingot out.
"""

from std.collections import Dict
from std.sys import argv

from minecraft.conn import Conn
from minecraft.dial import Dialer
from minecraft.protocol.block_pos import BlockPos
from minecraft.protocol.container import (
    CONTAINER_CRAFTING_INPUT,
    CONTAINER_CREATED_OUTPUT,
    CONTAINER_FURNACE_FUEL,
    CONTAINER_FURNACE_INGREDIENT,
    CONTAINER_FURNACE_RESULT,
    CONTAINER_HOT_BAR,
    CONTAINER_INVENTORY,
    CONTAINER_LEVEL_ENTITY,
    CONTAINER_TYPE_CONTAINER,
    CONTAINER_TYPE_FURNACE,
    FullContainerName,
)
from minecraft.protocol.inventory import (
    USE_ITEM_ACTION_CLICK_BLOCK,
    InventoryTransactionData,
    UseItemTransactionData,
)
from minecraft.protocol.item_descriptor import (
    DefaultItemDescriptor,
    ItemTagItemDescriptor,
)
from minecraft.protocol.item_stack import (
    ITEM_STACK_RESPONSE_STATUS_OK,
    CraftCreativeStackRequestAction,
    CraftRecipeStackRequestAction,
    DestroyStackRequestAction,
    ItemStackRequest as StackRequest,
    PlaceStackRequestAction,
    StackRequestAction,
    StackRequestSlotInfo,
    TakeStackRequestAction,
)
from minecraft.protocol.item import ItemInstance
from minecraft.protocol.math import Vec3
from minecraft.protocol.packet.command_request import CommandRequest
from minecraft.protocol.packet.container_close import ContainerClose
from minecraft.protocol.packet.container_open import ContainerOpen
from minecraft.protocol.packet.container_set_data import ContainerSetData
from minecraft.protocol.packet.crafting_data import CraftingData
from minecraft.protocol.packet.creative_content import CreativeContent
from minecraft.protocol.packet.id import (
    ID_CONTAINER_CLOSE,
    ID_CONTAINER_OPEN,
    ID_CONTAINER_SET_DATA,
    ID_CRAFTING_DATA,
    ID_CREATIVE_CONTENT,
    ID_INVENTORY_CONTENT,
    ID_INVENTORY_SLOT,
    ID_ITEM_STACK_RESPONSE,
    ID_SET_PLAYER_GAME_TYPE,
)
from minecraft.protocol.packet.inventory_content import InventoryContent
from minecraft.protocol.packet.inventory_slot import InventorySlot
from minecraft.protocol.packet.inventory_transaction import (
    InventoryTransaction,
)
from minecraft.protocol.packet.item_stack_request import ItemStackRequest
from minecraft.protocol.packet.item_stack_response import ItemStackResponse
from minecraft.protocol.packet.packet import PacketData
from minecraft.protocol.packet.player_auth_input import PlayerAuthInput
from minecraft.protocol.packet.set_player_game_type import (
    GAME_TYPE_CREATIVE,
    SetPlayerGameType,
)
from nethernet.os.time import monotonic_ms

comptime FACE_UP = 1


def check(ok: Bool, name: String) raises:
    """Prints PASS or raises FAIL."""
    if not ok:
        raise Error(t"FAIL {name}")
    print("PASS", name)


def _key(container: UInt8, slot: Int) -> Int:
    return Int(container) * 256 + slot


struct Bot(Movable):
    var conn: Conn
    var eye: Vec3
    var names: Dict[Int32, String]
    var creative_ids: Dict[String, UInt32]
    var crafting: Optional[CraftingData]
    var creative: Bool
    var ok: Optional[Bool]
    var ids: Dict[Int, Int32]
    var counts: Dict[Int, Int]
    var window: Optional[Tuple[UInt8, UInt8]]
    var window_slots: Dict[Int, Tuple[Int32, Int, String]]
    var closed: Bool
    var data: Dict[Int32, Int32]
    var next_request: Int32

    def __init__(out self, address: String, name: String) raises:
        var d = Dialer()
        d.identity_data.display_name = name.copy()
        self.conn = d.dial(address)
        self.eye = self.conn.game_data.player_position
        self.names = Dict[Int32, String]()
        for ref e in self.conn.game_data.items:
            self.names[Int32(e.runtime_id)] = e.name.copy()
        self.creative_ids = Dict[String, UInt32]()
        self.crafting = None
        self.creative = False
        self.ok = None
        self.ids = Dict[Int, Int32]()
        self.counts = Dict[Int, Int]()
        self.window = None
        self.window_slots = Dict[Int, Tuple[Int32, Int, String]]()
        self.closed = False
        self.data = Dict[Int32, Int32]()
        self.next_request = -1
        print("JOINED", name, self.eye)

    def handle(mut self, pk: PacketData) raises:
        var sid = self.conn.shield_id
        var id = pk.id()
        if id == ID_CREATIVE_CONTENT:
            var c = pk.decode[CreativeContent](sid, False)
            for ref it in c.items:
                var n = self.names.get(it.item.item_type.network_id)
                if n and n.value() not in self.creative_ids:
                    self.creative_ids[n.value()] = it.creative_item_network_id
        elif id == ID_CRAFTING_DATA:
            self.crafting = pk.decode[CraftingData](sid, False)
        elif id == ID_SET_PLAYER_GAME_TYPE:
            var g = pk.decode[SetPlayerGameType](sid, False)
            self.creative = g.game_type == GAME_TYPE_CREATIVE
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
        elif id == ID_INVENTORY_SLOT:
            var s = pk.decode[InventorySlot](sid, False)
            if self.window and s.window_id == UInt32(self.window.value()[0]):
                self._window_slot(Int(s.slot), s.new_item)
            elif s.window_id == 0:
                # The server changed the inventory itself, such as when
                # closing a window moves the UI items back (Go
                # MoveItemsToInventory).
                var c = CONTAINER_HOT_BAR if s.slot < 9 else CONTAINER_INVENTORY
                var k = _key(c, Int(s.slot))
                self.ids[k] = s.new_item.stack_network_id
                self.counts[k] = Int(s.new_item.stack.count)
        elif id == ID_CONTAINER_SET_DATA:
            var d = pk.decode[ContainerSetData](sid, False)
            self.data[d.key] = d.value

    def _window_slot(mut self, slot: Int, it: ItemInstance):
        var name = String()
        if it.stack.item_type.network_id != 0:
            name = self.names.get(it.stack.item_type.network_id).or_else("")
        self.window_slots[slot] = (
            it.stack_network_id,
            Int(it.stack.count),
            name^,
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

    def request(mut self, var actions: List[StackRequestAction]) raises -> Bool:
        """Sends one request and waits for its response."""
        var r = StackRequest()
        r.request_id = self.next_request
        self.next_request -= 2
        for ref a in actions:
            r.actions.append(a.copy())
        var pk = ItemStackRequest()
        pk.requests.append(r^)
        self.ok = None
        self.conn.write_packet(pk)
        var deadline = monotonic_ms() + 2000
        while not self.ok and monotonic_ms() < deadline:
            self.pump(20)
        return Bool(self.ok) and self.ok.value()

    def pick(mut self, name: String, hotbar: Int, count: Int) raises -> Bool:
        """Takes `count` of a creative item into a hotbar slot."""
        var net = self.creative_ids.get(name)
        if not net:
            raise Error(t"FAIL no creative item {name}")
        var req = self.next_request
        var craft = CraftCreativeStackRequestAction()
        craft.creative_item_network_id = net.value()
        craft.number_of_crafts = 1
        var take = TakeStackRequestAction()
        take.count = UInt8(count)
        take.source = slot(CONTAINER_CREATED_OUTPUT, 50, req)
        take.destination = slot(
            CONTAINER_HOT_BAR, hotbar, self.id_of(CONTAINER_HOT_BAR, hotbar)
        )
        return self.request(
            [StackRequestAction(craft^), StackRequestAction(take^)]
        )

    def move(
        mut self,
        src_c: UInt8,
        src: Int,
        src_id: Int32,
        dst_c: UInt8,
        dst: Int,
        count: Int,
    ) raises -> Bool:
        """Places `count` items from one slot into another."""
        var p = PlaceStackRequestAction()
        p.count = UInt8(count)
        p.source = slot(src_c, src, src_id)
        p.destination = slot(dst_c, dst, self.id_of(dst_c, dst))
        return self.request([StackRequestAction(p^)])

    def clear_hand(mut self) raises -> Bool:
        """Destroys the stack in hotbar slot 0 (creative only)."""
        var d = DestroyStackRequestAction()
        d.count = UInt8(self.counts.get(_key(CONTAINER_HOT_BAR, 0)).or_else(1))
        d.source = slot(CONTAINER_HOT_BAR, 0, self.id_of(CONTAINER_HOT_BAR, 0))
        return self.request([StackRequestAction(d^)])

    def click(mut self, pos: BlockPos) raises:
        """Uses the held item on the top face of a block (UseItem)."""
        var use = UseItemTransactionData()
        use.action_type = USE_ITEM_ACTION_CLICK_BLOCK
        use.block_position = pos.copy()
        use.block_face = FACE_UP
        use.hot_bar_slot = 0
        use.position = self.eye
        var tr = InventoryTransaction()
        tr.transaction_data = InventoryTransactionData(use^)
        self.conn.write_packet(tr)

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

    def recipe(self, output: String, input_count: Int) raises -> UInt32:
        """Returns the network ID of the first crafting table recipe giving
        `output` from `input_count` inputs."""
        ref data = self.crafting.value()
        for ref r in data.shapeless_recipes:
            if r.block != "crafting_table" or len(r.output) == 0:
                continue
            var name = self.names.get(r.output[0].item_type.network_id)
            if name and name.value() == output and len(r.input) == input_count:
                return r.recipe_network_id
        for ref r in data.shaped_recipes:
            if r.block != "crafting_table" or len(r.output) == 0:
                continue
            var name = self.names.get(r.output[0].item_type.network_id)
            if name and name.value() == output and len(r.input) == input_count:
                return r.recipe_network_id
        raise Error(t"FAIL no recipe for {output}")


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


def main() raises:
    var args = argv()
    var address = String(args[1])
    var x = Int(args[2])
    var y = Int(args[3])
    var z = Int(args[4])
    var bot = Bot(address, "Crafter")
    bot.pump(1500)
    var cmd = CommandRequest()
    cmd.command_line = "/gamemode creative"
    bot.conn.write_packet(cmd)
    bot.pump(1000)
    check(bot.creative, "/gamemode creative")
    check(Bool(bot.crafting), "CraftingData arrived")

    # Place a chest on X Y Z and a furnace two blocks east.
    var chest = block_pos(x, y + 1, z)
    var furnace = block_pos(x + 2, y + 1, z)
    check(bot.pick("minecraft:chest", 0, 1), "a chest from the creative menu")
    bot.click(block_pos(x, y, z))
    bot.idle(300)
    check(bot.clear_hand(), "the hand is emptied")
    check(
        bot.pick("minecraft:furnace", 0, 1), "a furnace from the creative menu"
    )
    bot.click(block_pos(x + 2, y, z))
    bot.idle(300)
    check(bot.clear_hand(), "the hand is emptied again")
    check(bot.pick("minecraft:oak_log", 1, 8), "8 oak logs")
    check(bot.pick("minecraft:coal", 2, 2), "2 coal")
    check(bot.pick("minecraft:raw_iron", 3, 1), "1 raw iron")

    # The chest: open, put 4 logs in, take 2 back, close, open again.
    bot.click(chest)
    bot.idle(500)
    check(
        Bool(bot.window) and bot.window.value()[1] == CONTAINER_TYPE_CONTAINER,
        "the chest opens (ContainerOpen)",
    )
    check(len(bot.window_slots) == 27, "the chest's 27 slots are sent")
    check(
        bot.move(
            CONTAINER_HOT_BAR,
            1,
            bot.id_of(CONTAINER_HOT_BAR, 1),
            CONTAINER_LEVEL_ENTITY,
            0,
            4,
        ),
        "4 logs go into the chest",
    )
    check(
        bot.counts.get(_key(CONTAINER_LEVEL_ENTITY, 0)).or_else(0) == 4,
        "the chest slot holds 4",
    )
    check(
        bot.move(
            CONTAINER_LEVEL_ENTITY,
            0,
            bot.id_of(CONTAINER_LEVEL_ENTITY, 0),
            CONTAINER_HOT_BAR,
            4,
            2,
        ),
        "2 logs come back out",
    )
    bot.close_window()
    check(bot.closed, "the chest closes (ContainerClose)")
    bot.click(chest)
    bot.idle(500)
    var kept = bot.window_slots.get(0)
    check(
        Bool(kept)
        and kept.value()[1] == 2
        and kept.value()[2] == "minecraft:oak_log",
        "reopened, the chest still holds 2 logs",
    )
    bot.close_window()

    # Crafting: a log into the 2x2 grid gives 4 planks; 4 planks give a
    # crafting table.
    check(
        bot.move(
            CONTAINER_HOT_BAR,
            1,
            bot.id_of(CONTAINER_HOT_BAR, 1),
            CONTAINER_CRAFTING_INPUT,
            28,
            1,
        ),
        "a log into the crafting grid",
    )
    var planks_id = bot.recipe("minecraft:oak_planks", 1)
    var req = bot.next_request
    var craft = CraftRecipeStackRequestAction()
    craft.recipe_network_id = planks_id
    craft.number_of_crafts = 1
    var take = TakeStackRequestAction()
    take.count = 4
    take.source = slot(CONTAINER_CREATED_OUTPUT, 50, req)
    take.destination = slot(CONTAINER_HOT_BAR, 5, 0)
    check(
        bot.request([StackRequestAction(craft^), StackRequestAction(take^)]),
        "crafting planks is accepted",
    )
    check(
        bot.counts.get(_key(CONTAINER_HOT_BAR, 5)).or_else(0) == 4,
        "4 planks land in the hotbar",
    )
    var actions = List[StackRequestAction]()
    for i in range(4):
        var p = PlaceStackRequestAction()
        p.count = 1
        # Later places refer to the stack the earlier ones changed.
        p.source = slot(
            CONTAINER_HOT_BAR,
            5,
            bot.id_of(CONTAINER_HOT_BAR, 5) if i == 0 else bot.next_request,
        )
        p.destination = slot(CONTAINER_CRAFTING_INPUT, 28 + i, 0)
        actions.append(StackRequestAction(p^))
    check(bot.request(actions^), "4 planks into the crafting grid")
    var table_id = bot.recipe("minecraft:crafting_table", 4)
    req = bot.next_request
    var craft2 = CraftRecipeStackRequestAction()
    craft2.recipe_network_id = table_id
    craft2.number_of_crafts = 1
    var take2 = TakeStackRequestAction()
    take2.count = 1
    take2.source = slot(CONTAINER_CREATED_OUTPUT, 50, req)
    take2.destination = slot(CONTAINER_HOT_BAR, 6, 0)
    check(
        bot.request([StackRequestAction(craft2^), StackRequestAction(take2^)]),
        "crafting a crafting table is accepted",
    )
    check(
        bot.counts.get(_key(CONTAINER_HOT_BAR, 6)).or_else(0) == 1,
        "the crafting table lands in the hotbar",
    )

    # The furnace: raw iron and coal in, an iron ingot out after 10 s.
    bot.click(furnace)
    bot.idle(500)
    check(
        Bool(bot.window) and bot.window.value()[1] == CONTAINER_TYPE_FURNACE,
        "the furnace opens",
    )
    check(
        bot.move(
            CONTAINER_HOT_BAR,
            3,
            bot.id_of(CONTAINER_HOT_BAR, 3),
            CONTAINER_FURNACE_INGREDIENT,
            0,
            1,
        ),
        "raw iron into the furnace",
    )
    check(
        bot.move(
            CONTAINER_HOT_BAR,
            2,
            bot.id_of(CONTAINER_HOT_BAR, 2),
            CONTAINER_FURNACE_FUEL,
            1,
            1,
        ),
        "coal into the furnace",
    )
    bot.idle(11000)
    check(len(bot.data) > 0, "the furnace shows its progress")
    var out = bot.window_slots.get(2)
    check(
        Bool(out)
        and out.value()[1] == 1
        and out.value()[2] == "minecraft:iron_ingot",
        "an iron ingot comes out",
    )
    check(
        bot.move(
            CONTAINER_FURNACE_RESULT,
            2,
            out.value()[0],
            CONTAINER_HOT_BAR,
            7,
            1,
        ),
        "the ingot is taken out",
    )
    bot.close_window()
    bot.conn.close()
    print("DONE")
