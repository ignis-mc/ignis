"""Item stack requests, ported from Dragonfly
`server/session/handler_item_stack_request.go` and the creative part of
`handler_crafting.go`.

The handler works on the session's `Inventories` and returns the
`ItemStackResponse`, so it runs without a connection. Stacks the player
drops are handed back for the server to spawn as item entities (Go
`Controllable.Drop`).

Ported actions: take, place, swap, drop, destroy, create, mine block,
craft creative; consume and the deprecated craft results are ignored as in
Go. Crafting, beacons, smithing, stonecutting, enchanting, looms and
grindstones need containers and recipes and reject the request.

Fixed Dragonfly bug: when a request is rejected, a slot it changed twice
is restored to its state before the request; Go restores the state before
the slot's last change.

Go keys its change maps by inventory pointer and iterates them in random
order; here keys pack the inventory kind and slot, and response containers
come in the order they were first changed.
"""

from std.collections import Dict

from minecraft.protocol.container import (
    CONTAINER_CREATED_OUTPUT,
    CONTAINER_INVENTORY,
    FullContainerName,
)
from minecraft.protocol.item_stack import (
    ITEM_STACK_RESPONSE_STATUS_ERROR,
    ITEM_STACK_RESPONSE_STATUS_OK,
    ConsumeStackRequestAction,
    CraftCreativeStackRequestAction,
    CraftResultsDeprecatedStackRequestAction,
    CreateStackRequestAction,
    DestroyStackRequestAction,
    DropStackRequestAction,
    ItemStackRequest,
    ItemStackResponse,
    MineBlockStackRequestAction,
    PlaceStackRequestAction,
    StackRequestSlotInfo,
    StackResponseContainerInfo,
    StackResponseSlotInfo,
    SwapStackRequestAction,
    TakeStackRequestAction,
)
from minecraft.protocol.packet.item_stack_request import (
    ItemStackRequest as ItemStackRequestPacket,
)
from minecraft.protocol.packet.item_stack_response import (
    ItemStackResponse as ItemStackResponsePacket,
)

from ..item.stack import Stack
from .inventory import (
    INV_OFF_HAND,
    Inventories,
    inventory_kind,
    window_inventory_kind,
)
from .window import Window

comptime CRAFTING_RESULT = 50
"""The UI slot of a crafting result (Go `craftingResult`)."""
comptime _ACK_TIMEOUT_MS = 5000
comptime _MAX_RESPONSE_CHANGES = 256


@fieldwise_init
struct _ChangeInfo(Copyable):
    """Go `changeInfo`, with where it happened."""

    var container: UInt8
    var kind: Int
    var slot: Int
    var after: StackResponseSlotInfo
    var before: Stack


@fieldwise_init
struct _ResponseChange(Copyable):
    """Go `responseChange`."""

    var id: Int32
    var timestamp: Int


def _change_key(container: UInt8, slot: UInt8) -> Int:
    return (Int(container) << 8) | Int(slot)


def _response_key(request: Int32, kind: Int, slot: UInt8) -> Int:
    return (Int(request) << 16) | (kind << 8) | Int(slot)


struct ItemStackRequestHandler(Defaultable, Movable):
    """Resolves the client's item stack requests (Go
    `ItemStackRequestHandler`)."""

    var _current_request: Int32
    var _changes: Dict[Int, _ChangeInfo]
    var _change_order: List[Int]
    var _response_changes: Dict[Int, _ResponseChange]
    var _pending_results: List[Stack]
    var _current: Int
    var _ignore_destroy: Bool
    var _creative: Bool
    var _window: Window

    def __init__(out self):
        """Creates a handler with no pending changes."""
        self._current_request = 0
        self._changes = Dict[Int, _ChangeInfo]()
        self._change_order = List[Int]()
        self._response_changes = Dict[Int, _ResponseChange]()
        self._pending_results = List[Stack]()
        self._current = 0
        self._ignore_destroy = False
        self._creative = False
        self._window = Window.none()

    def handle(
        mut self,
        pk: ItemStackRequestPacket,
        mut invs: Inventories,
        creative_inventory: Bool,
        creative_items: List[Stack],
        now_ms: Int,
        mut drops: List[Stack],
    ) -> ItemStackResponsePacket:
        """Resolves every request of the packet (Go `Handle`): each is
        answered OK with its changed slots, or rejected and reverted.
        `creative_inventory` is the game mode's `CreativeInventory`;
        dropped stacks are appended to `drops`."""
        self._current = now_ms
        self._creative = creative_inventory
        self._window = invs.window
        var out = ItemStackResponsePacket()
        for ref req in pk.requests:
            self._current_request = req.request_id
            var dropped = List[Stack]()
            try:
                self._handle_request(req, invs, creative_items, dropped)
                out.responses.append(self._resolve(req.request_id))
                self._ignore_destroy = False
                drops.extend(dropped^)
            except:
                # Out-of-sync stacks are common; Go only debugs the error.
                out.responses.append(self._reject(req.request_id, invs))
        return out^

    def _handle_request(
        mut self,
        req: ItemStackRequest,
        mut invs: Inventories,
        creative_items: List[Stack],
        mut drops: List[Stack],
    ) raises:
        for ref action in req.actions:
            ref v = action.value
            if v.isa[TakeStackRequestAction]():
                ref a = v[TakeStackRequestAction]
                self._transfer(a.source, a.destination, a.count, invs)
            elif v.isa[PlaceStackRequestAction]():
                ref a = v[PlaceStackRequestAction]
                self._transfer(a.source, a.destination, a.count, invs)
            elif v.isa[SwapStackRequestAction]():
                ref a = v[SwapStackRequestAction]
                self._swap(a.source, a.destination, invs)
            elif v.isa[DestroyStackRequestAction]():
                ref a = v[DestroyStackRequestAction]
                self._destroy(a.source, a.count, invs)
            elif v.isa[DropStackRequestAction]():
                ref a = v[DropStackRequestAction]
                self._drop(a.source, a.count, invs, drops)
            elif v.isa[CraftCreativeStackRequestAction]():
                ref a = v[CraftCreativeStackRequestAction]
                self._creative_craft(
                    a.creative_item_network_id, invs, creative_items
                )
            elif v.isa[MineBlockStackRequestAction]():
                ref a = v[MineBlockStackRequestAction]
                self._mine_block(a, invs)
            elif v.isa[CreateStackRequestAction]():
                self._create(
                    Int(v[CreateStackRequestAction].results_slot), invs
                )
            elif (
                v.isa[ConsumeStackRequestAction]()
                or v.isa[CraftResultsDeprecatedStackRequestAction]()
            ):
                pass
            else:
                raise Error(
                    t"unhandled stack request action {action.type_id()}"
                )

    def _transfer(
        mut self,
        src: StackRequestSlotInfo,
        dst: StackRequestSlotInfo,
        count: UInt8,
        mut invs: Inventories,
    ) raises:
        """Go `handleTransfer`."""
        self._verify(src, invs)
        self._verify(dst, invs)
        var i = self._item(src, invs)
        var dest = self._item(dst, invs)
        var n = Int(count)
        if not i.comparable(dest):
            raise Error("transferring incomparable stacks")
        if i.count() < n:
            raise Error(t"subtracting {n} from {i.count()} items")
        if not dest.empty() and dest.count() + n > dest.max_count():
            raise Error(t"adding {n} to {dest.count()} exceeds the max")
        if dest.empty():
            dest = i.grow(-i.count())
        self._set(src, i.grow(-n), invs)
        self._set(dst, dest.grow(n), invs)

    def _swap(
        mut self,
        src: StackRequestSlotInfo,
        dst: StackRequestSlotInfo,
        mut invs: Inventories,
    ) raises:
        """Go `handleSwap`."""
        self._verify(src, invs)
        self._verify(dst, invs)
        var i = self._item(src, invs)
        var dest = self._item(dst, invs)
        self._set(src, dest, invs)
        self._set(dst, i, invs)

    def _destroy(
        mut self, src: StackRequestSlotInfo, count: UInt8, mut invs: Inventories
    ) raises:
        """Go `handleDestroy`: creative only."""
        if self._ignore_destroy:
            return
        if not self._creative:
            raise Error("can only destroy items in gamemode creative/spectator")
        self._verify(src, invs)
        var i = self._item(src, invs)
        if i.count() < Int(count):
            raise Error(t"destroying {count} of {i.count()} items")
        self._set(src, i.grow(-Int(count)), invs)

    def _drop(
        mut self,
        src: StackRequestSlotInfo,
        count: UInt8,
        mut invs: Inventories,
        mut drops: List[Stack],
    ) raises:
        """Go `handleDrop`."""
        self._verify(src, invs)
        var i = self._item(src, invs)
        var n = Int(count)
        if i.count() < n:
            raise Error(t"dropping {n} of {i.count()} items")
        drops.append(i.grow(n - i.count()))
        self._set(src, i.grow(-n), invs)

    def _creative_craft(
        mut self,
        network_id: UInt32,
        mut invs: Inventories,
        creative_items: List[Stack],
    ) raises:
        """Go `handleCreativeCraft`: a full stack of the creative item."""
        if not self._creative:
            raise Error("can only craft creative items in gamemode creative")
        var index = Int(network_id) - 1
        if index < 0 or index >= len(creative_items):
            raise Error(t"creative item with network ID {network_id}")
        var it = creative_items[index].copy()
        it = it.grow(it.max_count() - it.count())
        self._pending_results.append(it^)
        self._create(len(self._pending_results) - 1, invs)

    def _mine_block(
        mut self, a: MineBlockStackRequestAction, mut invs: Inventories
    ) raises:
        """Go `handleMineBlock`: resends the hotbar slot in the response."""
        var slot = StackRequestSlotInfo()
        slot.container = FullContainerName()
        slot.container.container_id = CONTAINER_INVENTORY
        slot.slot = UInt8(a.hotbar_slot)
        slot.stack_network_id = a.stack_network_id
        self._verify(slot, invs)
        self._set(slot, self._item(slot, invs), invs)

    def _create(mut self, slot: Int, mut invs: Inventories) raises:
        """Go `handleCreate`: moves a pending result to the created output."""
        if slot >= len(self._pending_results):
            raise Error(t"invalid pending result slot: {slot}")
        var res = self._pending_results[slot].copy()
        if res.empty():
            raise Error(t"tried duplicating created result: {slot}")
        self._pending_results[slot] = Stack()
        var out = StackRequestSlotInfo()
        out.container = FullContainerName()
        out.container.container_id = CONTAINER_CREATED_OUTPUT
        out.slot = UInt8(CRAFTING_RESULT)
        self._set(out, res, invs)

    # --- Slots -------------------------------------------------------------

    def _kind(self, slot: StackRequestSlotInfo) raises -> Int:
        var kind = inventory_kind(slot.container.container_id)
        if not kind:
            kind = window_inventory_kind(
                slot.container.container_id, self._window
            )
        if not kind:
            raise Error(
                t"unable to find container with ID"
                t" {slot.container.container_id}"
            )
        return kind.value()

    def _index(self, kind: Int, slot: StackRequestSlotInfo) -> Int:
        if kind == INV_OFF_HAND:
            return 0
        return Int(slot.slot)

    def _item(
        self, slot: StackRequestSlotInfo, invs: Inventories
    ) raises -> Stack:
        """Go `itemInSlot`."""
        var kind = self._kind(slot)
        return invs.get(kind).item(self._index(kind, slot))

    def _verify(mut self, slot: StackRequestSlotInfo, invs: Inventories) raises:
        """Go `verifySlot`: the client's stack network ID must match."""
        self._try_acknowledge(slot)
        if len(self._response_changes) > _MAX_RESPONSE_CHANGES:
            raise Error("too many unacknowledged request slot changes")
        var kind = self._kind(slot)
        var i = self._item(slot, invs)
        var client_id = self._resolve_id(kind, slot)
        if i.id() != client_id:
            raise Error(
                t"stack ID mismatch: client expected {client_id}, but server"
                t" had {i.id()}"
            )

    def _resolve_id(
        self, kind: Int, slot: StackRequestSlotInfo
    ) raises -> Int32:
        """Go `resolveID`: a negative ID refers to an earlier request."""
        if slot.stack_network_id >= 0:
            return slot.stack_network_id
        var key = _response_key(slot.stack_network_id, kind, slot.slot)
        if case .Some(c) = self._response_changes.get(key):
            return c.id
        raise Error(
            t"slot pointed to stack request {slot.stack_network_id}, but it"
            t" did not change container {slot.container.container_id} slot"
            t" {slot.slot}"
        )

    def _try_acknowledge(mut self, slot: StackRequestSlotInfo) raises:
        """Go `tryAcknowledgeChanges`: drops cached response changes the
        client has now seen, and those older than five seconds."""
        var kind = self._kind(slot)
        var gone = List[Int]()
        for ref e in self._response_changes.items():
            var k = e.key
            var same = (k & 0xFF) == Int(slot.slot) and (
                (k >> 8) & 0xFF
            ) == kind
            if (
                same and slot.stack_network_id >= 0
            ) or self._current - e.value.timestamp > _ACK_TIMEOUT_MS:
                gone.append(k)
        for k in gone:
            _ = self._response_changes.pop(k)

    def _set(
        mut self, slot: StackRequestSlotInfo, it: Stack, mut invs: Inventories
    ) raises:
        """Go `setItemInSlot`: stores the stack and records the change for
        the response and for later requests that refer to it."""
        var kind = self._kind(slot)
        var index = self._index(kind, slot)
        ref inv = invs.get(kind)
        var before = inv.item(index)
        inv.set_item(index, it)
        var stored = inv.item(index)
        var info = StackResponseSlotInfo()
        info.slot = slot.slot
        info.hotbar_slot = slot.slot
        info.count = UInt8(stored.count())
        info.stack_network_id = stored.id()
        info.durability_correction = Int32(
            stored.max_durability() - stored.durability()
        )
        var key = _change_key(slot.container.container_id, slot.slot)
        if key in self._changes:
            # Keep the oldest `before`, which a rejection restores.
            before = self._changes[key].before.copy()
        else:
            self._change_order.append(key)
        self._changes[key] = _ChangeInfo(
            slot.container.container_id, kind, index, info^, before^
        )
        self._response_changes[
            _response_key(self._current_request, kind, slot.slot)
        ] = _ResponseChange(stored.id(), self._current)

    def _resolve(mut self, id: Int32) raises -> ItemStackResponse:
        """Go `resolve`: the OK response with every changed slot."""
        var resp = ItemStackResponse()
        resp.status = ITEM_STACK_RESPONSE_STATUS_OK
        resp.request_id = id
        var containers = List[UInt8]()
        for key in self._change_order:
            var c = UInt8(key >> 8)
            if c not in containers:
                containers.append(c)
        for c in containers:
            var info = StackResponseContainerInfo()
            info.container = FullContainerName()
            info.container.container_id = c
            for key in self._change_order:
                if UInt8(key >> 8) == c:
                    info.slot_info.append(self._changes[key].after.copy())
            resp.container_info.append(info^)
        self._changes = Dict[Int, _ChangeInfo]()
        self._change_order = List[Int]()
        self._pending_results = List[Stack]()
        return resp^

    def _reject(
        mut self, id: Int32, mut invs: Inventories
    ) -> ItemStackResponse:
        """Go `reject`: an error response; changes already made revert."""
        var resp = ItemStackResponse()
        resp.status = ITEM_STACK_RESPONSE_STATUS_ERROR
        resp.request_id = id
        for key in self._change_order:
            if case .Some(c) = self._changes.get(key):
                try:
                    invs.get(c.kind).set_item(c.slot, c.before)
                except:
                    pass
        self._changes = Dict[Int, _ChangeInfo]()
        self._change_order = List[Int]()
        self._pending_results = List[Stack]()
        return resp^
