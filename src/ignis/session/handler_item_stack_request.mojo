"""Item stack requests, ported from Dragonfly
`server/session/handler_item_stack_request.go` and the creative part of
`handler_crafting.go`.

The handler works on the session's `Inventories` and returns the
`ItemStackResponse`, so it runs without a connection. Stacks the player
drops are handed back for the server to spawn as item entities (Go
`Controllable.Drop`).

Ported actions: take, place, swap, drop, destroy, create, mine block,
craft creative, craft recipe and auto craft (with the dynamic decorated
pot recipe, `handler_crafting.go`); consume and the deprecated craft
results are ignored as in Go. Go's auto craft takes ingredients from the
crafting grid and the inventory in random map order; Ignis takes them from
the grid first.

Fixed Dragonfly bug: when a request is rejected, a slot it changed twice
is restored to its state before the request; Go restores the state before
the slot's last change.

Go keys its change maps by inventory pointer and iterates them in random
order; here keys pack the inventory kind and slot, and response containers
come in the order they were first changed.
"""

from std.collections import Dict

from minecraft.protocol.container import (
    CONTAINER_COMBINED_HOT_BAR_AND_INVENTORY,
    CONTAINER_CRAFTING_INPUT,
    CONTAINER_CREATED_OUTPUT,
    CONTAINER_INVENTORY,
    FullContainerName,
)
from minecraft.protocol.item_stack import (
    ITEM_STACK_RESPONSE_STATUS_ERROR,
    ITEM_STACK_RESPONSE_STATUS_OK,
    AutoCraftRecipeStackRequestAction,
    ConsumeStackRequestAction,
    CraftCreativeStackRequestAction,
    CraftRecipeStackRequestAction,
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

from std.memory import ArcPointer

from minecraft.nbt.nbt import TAG_STRING
from minecraft.nbt.tree import Tree

from ..block.decorated_pot import DecoratedPot
from ..block.hash import HASH_CRAFTING_TABLE
from ..block.register import VanillaBlocks
from ..item.brick import Brick
from ..item.pottery_sherd import PotterySherd
from ..item.recipe.item import Item as RecipeItem
from ..item.recipe.recipe import RecipeKind
from ..item.recipe.register import Recipes
from ..item.stack import Stack
from ..world.item import ItemRegistry
from .inventory import (
    INV_OFF_HAND,
    INV_OPENED,
    Inventories,
    inventory_kind,
    window_inventory_kind,
)
from .window import Window
from ..block.hash import HASH_SHULKER_BOX

comptime CRAFTING_RESULT = 50
"""The UI slot of a crafting result (Go `craftingResult`)."""
comptime CRAFTING_GRID_SIZE_SMALL = 4
"""The 2x2 grid of the inventory screen (Go `craftingGridSizeSmall`)."""
comptime CRAFTING_GRID_SIZE_LARGE = 9
"""The 3x3 grid of a crafting table (Go `craftingGridSizeLarge`)."""
comptime CRAFTING_GRID_SMALL_OFFSET = 28
"""The UI slot of the 2x2 grid (Go `craftingGridSmallOffset`)."""
comptime CRAFTING_GRID_LARGE_OFFSET = 32
"""The UI slot of the 3x3 grid (Go `craftingGridLargeOffset`)."""
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
    var _recipes: ArcPointer[Recipes]
    var _items: ArcPointer[ItemRegistry]

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
        self._recipes = ArcPointer(Recipes())
        self._items = ArcPointer(ItemRegistry())

    def use_recipes(
        mut self, recipes: ArcPointer[Recipes], items: ArcPointer[ItemRegistry]
    ):
        """Sets the recipes crafting requests use (Go `s.recipes`, numbered
        from 1) and the items their names come from."""
        self._recipes = recipes
        self._items = items

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
            elif v.isa[CraftRecipeStackRequestAction]():
                ref a = v[CraftRecipeStackRequestAction]
                self._craft(a.recipe_network_id, Int(a.number_of_crafts), invs)
            elif v.isa[AutoCraftRecipeStackRequestAction]():
                ref a = v[AutoCraftRecipeStackRequestAction]
                self._auto_craft(
                    a.recipe_network_id, Int(a.number_of_crafts), invs
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
        self._create_results([it^], invs)

    def _create_results(
        mut self, var results: List[Stack], mut invs: Inventories
    ) raises:
        """Go `createResults`: a single result goes to the created output at
        once; with several, the client asks for each with a create."""
        var n = len(results)
        self._pending_results.extend(results^)
        if n > 1:
            return
        self._create(0, invs)

    # --- Crafting (Go handler_crafting.go) ----------------------------------

    def _crafting_table_recipe(
        self, network_id: UInt32, times: Int
    ) raises -> Optional[Int]:
        # The checks shared by handleCraft and handleAutoCraft; None means
        # no recipe has the ID (a dynamic craft).
        var index = Int(network_id) - 1
        if index < 0 or index >= len(self._recipes[].recipes()):
            return None
        ref r = self._recipes[].recipes()[index]
        if r.kind != RecipeKind.SHAPED and r.kind != RecipeKind.SHAPELESS:
            raise Error(
                t"recipe with network id {network_id} is not a shaped or"
                t" shapeless recipe"
            )
        if r.block() != "crafting_table":
            raise Error(
                t"recipe with network id {network_id} is not a crafting"
                t" table recipe"
            )
        if times < 1:
            raise Error("times crafted must be at least 1")
        return index

    def _grid(self) -> Tuple[Int, Int]:
        # Go `craftingSize` and `craftingOffset`.
        if self._window.block == HASH_CRAFTING_TABLE:
            return (CRAFTING_GRID_SIZE_LARGE, CRAFTING_GRID_LARGE_OFFSET)
        return (CRAFTING_GRID_SIZE_SMALL, CRAFTING_GRID_SMALL_OFFSET)

    def _craft(
        mut self, network_id: UInt32, times: Int, mut invs: Inventories
    ) raises:
        """Go `handleCraft`: takes each input from the crafting grid."""
        var found = self._crafting_table_recipe(network_id, times)
        if not found:
            self._dynamic_craft(times, invs)
            return
        var r = self._recipes[].recipes()[found.value()].copy()
        var grid = self._grid()
        var size = grid[0]
        var offset = grid[1]
        var consumed = List[Bool](length=size, fill=False)
        for ref expected in r.input():
            var processed = False
            for slot in range(offset, offset + size):
                if consumed[slot - offset]:
                    continue
                var has = invs.ui.item(slot)
                if (
                    has.empty() != expected.empty()
                    or has.count() < expected.count() * times
                ):
                    continue
                if not self._matches(has, expected):
                    continue
                processed = True
                consumed[slot - offset] = True
                self._set(
                    _slot(CONTAINER_CRAFTING_INPUT, slot),
                    has.grow(-expected.count() * times),
                    invs,
                )
                break
            if not processed:
                raise Error(
                    t"recipe {network_id}: could not consume expected item"
                )
        self._create_results(repeat_stacks(r.output(), times), invs)

    def _auto_craft(
        mut self, network_id: UInt32, times: Int, mut invs: Inventories
    ) raises:
        """Go `handleAutoCraft`: takes the inputs, merged, from the grid and
        then the inventory."""
        var found = self._crafting_table_recipe(network_id, times)
        if not found:
            self._dynamic_craft(times, invs)
            return
        var r = self._recipes[].recipes()[found.value()].copy()
        var flattened = List[RecipeItem]()
        var counts = List[Int]()
        for ref i in r.input():
            if i.empty():
                continue
            var merged = False
            for k in range(len(flattened)):
                if self._same_input(flattened[k], i):
                    counts[k] += i.count()
                    merged = True
                    break
            if not merged:
                flattened.append(i.copy())
                counts.append(i.count())
        for k in range(len(flattened)):
            var remaining = counts[k] * times
            for container in [
                CONTAINER_CRAFTING_INPUT,
                CONTAINER_COMBINED_HOT_BAR_AND_INVENTORY,
            ]:
                var kind = inventory_kind(container).value()
                for slot in range(invs.get(kind).size()):
                    var has = invs.get(kind).item(slot)
                    if has.empty() or not self._matches(has, flattened[k]):
                        continue
                    var removal = min(has.count(), remaining)
                    remaining -= removal
                    self._set(_slot(container, slot), has.grow(-removal), invs)
                    if remaining == 0:
                        break
                if remaining == 0:
                    break
            if remaining != 0:
                raise Error(
                    t"recipe {network_id}: could not consume expected item"
                )
        self._create_results(repeat_stacks(r.output(), times), invs)

    def _dynamic_craft(mut self, times_in: Int, mut invs: Inventories) raises:
        """Go `tryDynamicCraft`: the decorated pot from four decorations."""
        var times = times_in
        if times < 1:
            raise Error("times crafted must be at least 1")
        var grid = self._grid()
        var size = grid[0]
        var offset = grid[1]
        var input = List[Stack]()
        for i in range(size):
            input.append(invs.ui.item(offset + i))
        if len(self._recipes[].dynamic_recipes()) == 0:
            raise Error("no matching recipe found for crafting grid")
        var output = self._decorated_pot(input)
        if not output:
            raise Error("no matching recipe found for crafting grid")
        var least = Int.MAX
        for ref it in input:
            if not it.empty() and it.count() < least:
                least = it.count()
        if least < times:
            times = least
        for i in range(size):
            var it = invs.ui.item(offset + i)
            if not it.empty():
                self._set(
                    _slot(CONTAINER_CRAFTING_INPUT, offset + i),
                    it.grow(-times),
                    invs,
                )
        self._create_results(
            repeat_stacks([output.value().copy()], times), invs
        )

    def _decorated_pot(self, input: List[Stack]) -> Optional[Stack]:
        # Go `DecoratedPotRecipe.Match`.
        if len(input) != 9:
            return None
        var names = List[String]()
        for i in range(9):
            ref it = input[i]
            if i % 2 == 0:
                if not it.empty():
                    return None
                continue
            if it.empty():
                return None
            var k = it.item().value().kind
            if k != Brick.BASE_HASH and k != PotterySherd.BASE_HASH:
                return None
            names.append(self._name(it))
        var nbt = Tree()
        try:
            _ = nbt.put_string(nbt.root(), "id", "DecoratedPot")
            var l = nbt.put_list(nbt.root(), "sherds", TAG_STRING)
            for idx in [0, 1, 3, 2]:  # top, left, bottom, right
                _ = nbt.append_string(l, names[idx])
        except:
            return None
        return Stack(DecoratedPot(), 1).with_item_nbt(nbt^)

    def _name(self, s: Stack) -> String:
        # Go `s.Item().EncodeItem()`'s name.
        if case .Some(it) = s.item():
            if it.block:
                if case .Some(e) = VanillaBlocks.encode_block_item(
                    it.kind, it.hash
                ):
                    return e.name
                return String()
            if case .Some(e) = self._items[].encode_item(it):
                return e.name
        return String()

    def _matches(self, has: Stack, expected: RecipeItem) -> Bool:
        # Go `matchingStacks` with a stack from the inventory.
        if case .Some(t) = expected.tag():
            return t.contains(self._name(has))
        var e = expected.stack().value().copy()
        if not expected.variants():
            return has.comparable(e)
        return self._name(has) == self._name(e)

    def _same_input(self, has: RecipeItem, expected: RecipeItem) -> Bool:
        # Go `matchingStacks` between two recipe inputs.
        if case .Some(t) = expected.tag():
            if case .Some(h) = has.tag():
                return h.tag() == t.tag()
            return t.contains(self._name(has.stack().value()))
        var e = expected.stack().value().copy()
        if case .Some(h) = has.tag():
            return h.contains(self._name(e))
        if not expected.variants():
            return has.stack().value().comparable(e)
        return self._name(has.stack().value()) == self._name(e)

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
        if (
            kind == INV_OPENED
            and self._window.block == HASH_SHULKER_BOX
            and _is_shulker_box(it)
        ):
            # Go's slot validator `canStoreInShulkerBox`.
            raise Error("shulker boxes cannot hold shulker boxes")
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


def _is_shulker_box(it: Stack) -> Bool:
    if case .Some(i) = it.item():
        return i.block and i.kind == HASH_SHULKER_BOX
    return False


def _slot(container: UInt8, slot: Int) -> StackRequestSlotInfo:
    var info = StackRequestSlotInfo()
    info.container = FullContainerName()
    info.container.container_id = container
    info.slot = UInt8(slot)
    return info^


def repeat_stacks(items: List[Stack], repetitions: Int) -> List[Stack]:
    """Returns the outputs of crafting `repetitions` times, split into full
    stacks (Go `repeatStacks`)."""
    var out = List[Stack]()
    for ref o in items:
        var count = o.count()
        var max_count = o.max_count()
        var total = count * repetitions
        var stacks = (total + max_count - 1) // max_count
        for _ in range(stacks):
            var inc = min(total, max_count)
            total -= inc
            out.append(o.grow(inc - count))
    return out^
