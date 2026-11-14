"""A bot that breaks, collects and places blocks, for `scripts/e2e.sh`.
Prints `PASS <check>` lines and fails on the first check that does not
hold.

    interact_bot.mojo survival ADDRESS X Y Z CRACK_DATA
        breaks the block at X Y Z in survival: the server must show the
        crack animation with CRACK_DATA (Go's 65535 / break ticks), remove
        the block when the client predicts the break, drop it as an item,
        let the bot pick it up, and place it back with UseItem.
    interact_bot.mojo creative-item ADDRESS X Y Z
        in creative, takes the first block of the creative inventory into
        the hotbar with ItemStackRequest (CraftCreative and Take), and
        places it on the block at X Y Z: the stack is not used up.
    interact_bot.mojo adventure ADDRESS X Y Z
        switches to adventure with /gamemode and tries to break the block:
        the server refuses and sends the block back.
    interact_bot.mojo creative ADDRESS X Y Z
        switches to creative with /gamemode and breaks the block at X Y Z:
        it goes at once, without cracking and without a drop.
"""

from minecraft.conn import Conn
from minecraft.dial import Dialer
from minecraft.protocol.block_pos import BlockPos
from minecraft.protocol.inventory import (
    USE_ITEM_ACTION_CLICK_BLOCK,
    InventoryTransactionData,
    UseItemTransactionData,
)
from minecraft.protocol.item import ItemInstance
from minecraft.protocol.math import Vec3
from minecraft.protocol.packet.add_item_actor import AddItemActor
from minecraft.protocol.packet.command_request import CommandRequest
from minecraft.protocol.packet.creative_content import CreativeContent
from minecraft.protocol.packet.item_stack_request import ItemStackRequest
from minecraft.protocol.packet.item_stack_response import ItemStackResponse
from minecraft.protocol.container import (
    CONTAINER_CREATED_OUTPUT,
    CONTAINER_HOT_BAR,
    FullContainerName,
)
from minecraft.protocol.item_stack import (
    ITEM_STACK_RESPONSE_STATUS_OK,
    CraftCreativeStackRequestAction,
    ItemStackRequest as StackRequest,
    StackRequestAction,
    StackRequestSlotInfo,
    TakeStackRequestAction,
)
from minecraft.protocol.packet.id import (
    ID_CREATIVE_CONTENT,
    ID_ITEM_STACK_RESPONSE,
)
from minecraft.protocol.packet.id import (
    ID_ADD_ITEM_ACTOR,
    ID_INVENTORY_CONTENT,
    ID_INVENTORY_SLOT,
    ID_LEVEL_EVENT,
    ID_SET_PLAYER_GAME_TYPE,
    ID_TAKE_ITEM_ACTOR,
    ID_UPDATE_BLOCK,
)
from minecraft.protocol.packet.inventory_slot import InventorySlot
from minecraft.protocol.packet.inventory_transaction import (
    InventoryTransaction,
)
from minecraft.protocol.packet.level_event import (
    LEVEL_EVENT_PARTICLES_DESTROY_BLOCK,
    LEVEL_EVENT_START_BLOCK_CRACKING,
    LevelEvent,
)
from minecraft.protocol.packet.packet import PacketData
from minecraft.protocol.packet.player_auth_input import (
    INPUT_FLAG_PERFORM_BLOCK_ACTIONS,
    PlayerAuthInput,
)
from minecraft.protocol.packet.set_player_game_type import (
    GAME_TYPE_CREATIVE,
    SetPlayerGameType,
)
from minecraft.protocol.packet.take_item_actor import TakeItemActor
from minecraft.protocol.packet.update_block import UpdateBlock
from minecraft.protocol.player import (
    PLAYER_ACTION_PREDICT_DESTROY_BLOCK,
    PLAYER_ACTION_START_BREAK,
    PlayerBlockAction,
)
from nethernet.os.time import monotonic_ms
from std.sys import argv

comptime FACE_UP = 1


def check(ok: Bool, name: String) raises:
    """Prints PASS or raises FAIL."""
    if not ok:
        raise Error(t"FAIL {name}")
    print("PASS", name)


struct Bot(Movable):
    var conn: Conn
    var eye: Vec3
    var cracks: List[Int32]
    var destroyed: Bool
    var updated: Bool
    var update_rid: UInt32
    var item_actor: Optional[UInt64]
    var taken: Bool
    var held_item: ItemInstance
    var creative: Bool
    var creative_items: List[Tuple[UInt32, Int32]]
    var response: Optional[UInt8]
    var hotbar_count: Int

    def __init__(out self, address: String, name: String) raises:
        var d = Dialer()
        d.identity_data.display_name = name.copy()
        self.conn = d.dial(address)
        self.eye = self.conn.game_data.player_position
        self.cracks = List[Int32]()
        self.destroyed = False
        self.updated = False
        self.update_rid = 0
        self.item_actor = None
        self.taken = False
        self.held_item = ItemInstance()
        self.creative = False
        self.creative_items = List[Tuple[UInt32, Int32]]()
        self.response = None
        self.hotbar_count = -1
        print("JOINED", name, self.eye)

    def reset(mut self):
        self.cracks.clear()
        self.destroyed = False
        self.updated = False
        self.item_actor = None
        self.taken = False

    def handle(mut self, pk: PacketData, target: BlockPos) raises:
        var sid = self.conn.shield_id
        var id = pk.id()
        if id == ID_LEVEL_EVENT:
            var e = pk.decode[LevelEvent](sid, False)
            if e.event_type == LEVEL_EVENT_START_BLOCK_CRACKING:
                self.cracks.append(e.event_data)
            elif e.event_type == LEVEL_EVENT_PARTICLES_DESTROY_BLOCK:
                self.destroyed = True
        elif id == ID_UPDATE_BLOCK:
            var u = pk.decode[UpdateBlock](sid, False)
            if (
                u.position.x == target.x
                and u.position.y == target.y
                and u.position.z == target.z
            ):
                self.updated = True
                self.update_rid = u.new_block_runtime_id
        elif id == ID_ADD_ITEM_ACTOR:
            self.item_actor = pk.decode[AddItemActor](
                sid, False
            ).entity_runtime_id
        elif id == ID_TAKE_ITEM_ACTOR:
            self.taken = True
        elif id == ID_INVENTORY_SLOT:
            var s = pk.decode[InventorySlot](sid, False)
            if s.window_id == 0 and s.slot == 0:
                self.held_item = s.new_item.copy()
        elif id == ID_CREATIVE_CONTENT:
            var c = pk.decode[CreativeContent](sid, False)
            for ref it in c.items:
                self.creative_items.append(
                    (it.creative_item_network_id, it.item.block_runtime_id)
                )
        elif id == ID_ITEM_STACK_RESPONSE:
            var r = pk.decode[ItemStackResponse](sid, False)
            for ref resp in r.responses:
                self.response = resp.status
                for ref c in resp.container_info:
                    if c.container.container_id == CONTAINER_HOT_BAR:
                        for ref slot in c.slot_info:
                            if slot.slot == 0:
                                self.hotbar_count = Int(slot.count)
        elif id == ID_SET_PLAYER_GAME_TYPE:
            var g = pk.decode[SetPlayerGameType](sid, False)
            self.creative = g.game_type == GAME_TYPE_CREATIVE

    def pump(mut self, ms: Int, target: BlockPos) raises:
        var deadline = monotonic_ms() + ms
        while monotonic_ms() < deadline:
            var next = self.conn.read_packet(10)
            if next:
                self.handle(next.value(), target)

    def input(mut self, actions: List[PlayerBlockAction], eye: Vec3) raises:
        """Sends one PlayerAuthInput at `eye`, with block actions."""
        var pk = PlayerAuthInput()
        pk.position = eye
        if len(actions) > 0:
            pk.input_data.set(INPUT_FLAG_PERFORM_BLOCK_ACTIONS)
            pk.block_actions = actions.copy()
        self.conn.write_packet(pk)
        self.eye = eye

    def idle(mut self, ms: Int, target: BlockPos) raises:
        """Sends an input every tick for `ms`, standing still."""
        var deadline = monotonic_ms() + ms
        while monotonic_ms() < deadline:
            var here = self.eye
            self.input(List[PlayerBlockAction](), here)
            self.pump(50, target)


def action(a: Int32, pos: BlockPos) -> PlayerBlockAction:
    var b = PlayerBlockAction()
    b.action = a
    b.block_pos = pos.copy()
    b.face = FACE_UP
    return b^


def block_pos(x: Int, y: Int, z: Int) -> BlockPos:
    var b = BlockPos()
    b.x = Int32(x)
    b.y = Int32(y)
    b.z = Int32(z)
    return b^


def survival(address: String, target: BlockPos, crack: Int32) raises:
    var bot = Bot(address, "Breaker")
    bot.pump(1500, target)
    # Standing still puts the player on the ground server-side.
    bot.idle(300, target)
    bot.reset()
    var start = monotonic_ms()
    var here = bot.eye
    bot.input([action(PLAYER_ACTION_START_BREAK, target)], here)
    bot.idle(200, target)
    check(len(bot.cracks) == 1, "the server starts the crack animation")
    print("CRACK", bot.cracks[0])
    check(bot.cracks[0] == crack, String(t"crack speed {crack}"))
    check(not bot.updated, "the block stays until the break completes")
    # 65535 / crack ticks, as the client times it.
    var ms = Int(65535 / Int(crack)) * 50
    bot.idle(max(0, ms - (monotonic_ms() - start)), target)
    here = bot.eye
    bot.input([action(PLAYER_ACTION_PREDICT_DESTROY_BLOCK, target)], here)
    bot.idle(500, target)
    check(bot.updated and bot.destroyed, "the block breaks with particles")
    var air = bot.update_rid
    check(Bool(bot.item_actor), "the block drops as an item entity")
    # Step into the hole the block left; the item lies at its bottom.
    var feet = Vec3(
        Float32(target.x) + 0.5, Float32(target.y), Float32(target.z) + 0.5
    )
    var eye = Vec3(feet.x, feet.y + 1.62, feet.z)
    for i in range(1, 11):
        var f = Float32(i) / 10
        bot.input(
            List[PlayerBlockAction](),
            Vec3(
                bot.eye.x + (eye.x - bot.eye.x) * f,
                bot.eye.y + (eye.y - bot.eye.y) * f,
                bot.eye.z + (eye.z - bot.eye.z) * f,
            ),
        )
        bot.pump(50, target)
    bot.idle(2000, target)
    check(bot.taken, "the bot picks the item up (TakeItemActor)")
    check(
        bot.held_item.stack.count == 1,
        "the item lands in the hotbar (InventorySlot)",
    )
    # Back on the surface, place the block where it was, against the block
    # below the hole.
    var top = Vec3(eye.x, eye.y + 2, eye.z)
    bot.input(List[PlayerBlockAction](), top)
    bot.idle(300, target)
    bot.updated = False
    var below = block_pos(Int(target.x), Int(target.y) - 1, Int(target.z))
    var use = UseItemTransactionData()
    use.action_type = USE_ITEM_ACTION_CLICK_BLOCK
    use.block_position = below.copy()
    use.block_face = FACE_UP
    use.hot_bar_slot = 0
    use.held_item = bot.held_item.copy()
    use.position = top
    var tr = InventoryTransaction()
    tr.transaction_data = InventoryTransactionData(use^)
    bot.conn.write_packet(tr)
    bot.idle(500, target)
    check(
        bot.updated and bot.update_rid != air,
        "UseItem places the block back",
    )
    bot.conn.close()
    print("DONE")


def creative(address: String, target: BlockPos) raises:
    var bot = Bot(address, "Builder")
    bot.pump(1500, target)
    var req = CommandRequest()
    req.command_line = "/gamemode creative"
    bot.conn.write_packet(req)
    bot.pump(1000, target)
    check(bot.creative, "/gamemode creative")
    bot.reset()
    var here = bot.eye
    bot.input(
        [
            action(PLAYER_ACTION_START_BREAK, target),
            action(PLAYER_ACTION_PREDICT_DESTROY_BLOCK, target),
        ],
        here,
    )
    bot.idle(1500, target)
    check(len(bot.cracks) == 0, "no crack animation in creative")
    check(bot.updated and bot.destroyed, "the block breaks at once")
    check(not bot.item_actor, "nothing drops in creative")
    bot.conn.close()
    print("DONE")


def slot(container: UInt8, s: Int, id: Int32) -> StackRequestSlotInfo:
    var info = StackRequestSlotInfo()
    info.container = FullContainerName()
    info.container.container_id = container
    info.slot = UInt8(s)
    info.stack_network_id = id
    return info^


def creative_item(address: String, target: BlockPos) raises:
    var bot = Bot(address, "Creator")
    bot.pump(1500, target)
    var req = CommandRequest()
    req.command_line = "/gamemode creative"
    bot.conn.write_packet(req)
    bot.pump(1000, target)
    check(bot.creative, "/gamemode creative")
    print("CREATIVE ITEMS", len(bot.creative_items))
    var id = UInt32(0)
    for e in bot.creative_items:
        if e[1] > 0:
            id = e[0]
            break
    check(id > 0, "CreativeContent lists a block")
    # The vanilla client's creative pick: craft, then take the created stack
    # (referred to by this request's ID) into the hotbar.
    var r = StackRequest()
    r.request_id = -7
    var craft = CraftCreativeStackRequestAction()
    craft.creative_item_network_id = id
    craft.number_of_crafts = 1
    r.actions.append(StackRequestAction(craft^))
    var take = TakeStackRequestAction()
    take.count = 1
    take.source = slot(CONTAINER_CREATED_OUTPUT, 50, -7)
    take.destination = slot(CONTAINER_HOT_BAR, 0, 0)
    r.actions.append(StackRequestAction(take^))
    var pk = ItemStackRequest()
    pk.requests.append(r^)
    bot.conn.write_packet(pk)
    bot.pump(1000, target)
    check(
        Bool(bot.response)
        and bot.response.value() == ITEM_STACK_RESPONSE_STATUS_OK,
        "the creative request is accepted",
    )
    check(bot.hotbar_count == 1, "one creative item lands in the hotbar")
    bot.updated = False
    var top = BlockPos()
    top.x = target.x
    top.y = target.y + 1
    top.z = target.z
    var use = UseItemTransactionData()
    use.action_type = USE_ITEM_ACTION_CLICK_BLOCK
    use.block_position = target.copy()
    use.block_face = FACE_UP
    use.hot_bar_slot = 0
    use.held_item = bot.held_item.copy()
    use.position = bot.eye
    var tr = InventoryTransaction()
    tr.transaction_data = InventoryTransactionData(use^)
    bot.conn.write_packet(tr)
    bot.idle(800, top)
    check(bot.updated, "the creative block is placed")
    bot.conn.close()
    print("DONE")


def adventure(address: String, target: BlockPos) raises:
    var bot = Bot(address, "Visitor")
    bot.pump(1500, target)
    var req = CommandRequest()
    req.command_line = "/gamemode adventure"
    bot.conn.write_packet(req)
    bot.pump(1000, target)
    bot.reset()
    var here = bot.eye
    bot.input(
        [
            action(PLAYER_ACTION_START_BREAK, target),
            action(PLAYER_ACTION_PREDICT_DESTROY_BLOCK, target),
        ],
        here,
    )
    bot.idle(1500, target)
    check(not bot.destroyed, "adventure mode cannot break blocks")
    check(bot.updated, "the server sends the block back")
    bot.conn.close()
    print("DONE")


def main() raises:
    var args = argv()
    var mode = String(args[1])
    var address = String(args[2])
    var target = block_pos(Int(args[3]), Int(args[4]), Int(args[5]))
    if mode == "survival":
        survival(address, target, Int32(Int(args[6])))
    elif mode == "creative":
        creative(address, target)
    elif mode == "creative-item":
        creative_item(address, target)
    elif mode == "adventure":
        adventure(address, target)
    else:
        raise Error(t"unknown mode {mode}")
