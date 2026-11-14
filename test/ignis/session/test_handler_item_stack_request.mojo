from ignis.block.crafting_table import CraftingTable
from ignis.block.banner import Banner
from ignis.block.hash import (
    HASH_BEACON,
    HASH_ENCHANTING_TABLE,
    HASH_ANVIL,
    HASH_CRAFTING_TABLE,
    HASH_GRINDSTONE,
    HASH_LOOM,
    HASH_SMITHING_TABLE,
    HASH_STONECUTTER,
)
from ignis.block.stone import Stone
from ignis.item.smithing_template import SmithingTemplate
from ignis.block.log import Log
from ignis.block.planks import Planks
from ignis.item.banner_pattern import BannerPattern
from ignis.item.banner_pattern_type import BannerPatternType
from ignis.item.colour import Colour
from ignis.item.diamond import Diamond
from ignis.item.emerald import Emerald
from minecraft.protocol.item_stack import BeaconPaymentStackRequestAction
from ignis.item.dye import Dye
from ignis.item.book import Book
from ignis.item.enchanted_book import EnchantedBook
from ignis.item.lapis_lazuli import LapisLazuli
from ignis.session.enchanting import offers_for
from ignis.item.enchantment import (
    CURSE_OF_VANISHING_ID,
    EFFICIENCY_ID,
    UNBREAKING_ID,
)
from ignis.item.shears import Shears
from ignis.item.stack import Enchantment
from ignis.session.handler_item_stack_request import grindstone_experience
from ignis.item.recipe.item import Item as RecipeItem
from ignis.item.recipe.item_tag import ItemTags, new_item_tag
from ignis.item.recipe.recipe import (
    new_shaped,
    new_shapeless,
    new_smithing_transform,
)
from ignis.item.recipe.register import Recipes
from ignis.item.recipe.shape import Shape
from ignis.session.handler_item_stack_request import repeat_stacks
from ignis.session.window import WINDOW_UI, Window
from ignis.world.item import ItemRegistry
from std.memory import ArcPointer
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from ignis.session.handler_item_stack_request import (
    CRAFTING_RESULT,
    ItemStackRequestHandler,
)
from ignis.session.inventory import Inventories
from minecraft.protocol.container import (
    CONTAINER_CRAFTING_INPUT,
    CONTAINER_CREATED_OUTPUT,
    CONTAINER_CURSOR,
    CONTAINER_HOT_BAR,
    CONTAINER_INVENTORY,
    FullContainerName,
)
from minecraft.protocol.item_stack import (
    ITEM_STACK_RESPONSE_STATUS_ERROR,
    ITEM_STACK_RESPONSE_STATUS_OK,
    AutoCraftRecipeStackRequestAction,
    CraftCreativeStackRequestAction,
    CraftGrindstoneRecipeStackRequestAction,
    CraftLoomRecipeStackRequestAction,
    CraftRecipeOptionalStackRequestAction,
    CraftRecipeStackRequestAction,
    DestroyStackRequestAction,
    DropStackRequestAction,
    ItemStackRequest,
    PlaceStackRequestAction,
    StackRequestAction,
    StackRequestSlotInfo,
    SwapStackRequestAction,
    TakeStackRequestAction,
)
from minecraft.protocol.packet.item_stack_request import (
    ItemStackRequest as ItemStackRequestPacket,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def slot(container: UInt8, s: Int, id: Int32) -> StackRequestSlotInfo:
    var info = StackRequestSlotInfo()
    info.container = FullContainerName()
    info.container.container_id = container
    info.slot = UInt8(s)
    info.stack_network_id = id
    return info^


def packet(id: Int32, var action: StackRequestAction) -> ItemStackRequestPacket:
    var req = ItemStackRequest()
    req.request_id = id
    req.actions.append(action^)
    var pk = ItemStackRequestPacket()
    pk.requests.append(req^)
    return pk^


def take(
    count: Int, src: StackRequestSlotInfo, dst: StackRequestSlotInfo
) -> StackRequestAction:
    var a = TakeStackRequestAction()
    a.count = UInt8(count)
    a.source = src.copy()
    a.destination = dst.copy()
    return StackRequestAction(a^)


def run(
    mut h: ItemStackRequestHandler,
    pk: ItemStackRequestPacket,
    mut invs: Inventories,
    creative: Bool = False,
) -> Tuple[UInt8, List[Stack]]:
    var drops = List[Stack]()
    var out = h.handle(pk, invs, creative, [Stack(Diamond(), 1)], 0, drops)
    return (out.responses[0].status, drops^)


def test_take_half_to_cursor() raises:
    var invs = Inventories()
    invs.inv.set_item(0, Stack(Stick(), 10))
    var id = invs.inv.item(0).id()
    var h = ItemStackRequestHandler()
    var drops = List[Stack]()
    var out = h.handle(
        packet(
            -1,
            take(
                4, slot(CONTAINER_HOT_BAR, 0, id), slot(CONTAINER_CURSOR, 0, 0)
            ),
        ),
        invs,
        False,
        List[Stack](),
        0,
        drops,
    )
    ref r = out.responses[0]
    assert_equal(r.status, ITEM_STACK_RESPONSE_STATUS_OK)
    assert_equal(r.request_id, -1)
    assert_equal(invs.inv.item(0).count(), 6)
    assert_equal(invs.ui.item(0).count(), 4)
    assert_equal(len(r.container_info), 2)
    assert_equal(r.container_info[0].container.container_id, CONTAINER_HOT_BAR)
    assert_equal(r.container_info[0].slot_info[0].count, 6)
    assert_equal(
        r.container_info[0].slot_info[0].stack_network_id,
        invs.inv.item(0).id(),
    )
    assert_equal(r.container_info[1].slot_info[0].count, 4)
    # A later request may refer to the cursor stack by this request's ID.
    var a = PlaceStackRequestAction()
    a.count = 4
    a.source = slot(CONTAINER_CURSOR, 0, -1)
    a.destination = slot(CONTAINER_INVENTORY, 20, 0)
    assert_equal(
        run(h, packet(-3, StackRequestAction(a^)), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_OK,
    )
    assert_true(invs.ui.item(0).empty())
    assert_equal(invs.inv.item(20).count(), 4)


def test_stale_id_is_rejected_and_reverted() raises:
    var invs = Inventories()
    invs.inv.set_item(0, Stack(Stick(), 10))
    var id = invs.inv.item(0).id()
    var h = ItemStackRequestHandler()
    var req = ItemStackRequest()
    req.request_id = -5
    # The first action is valid, the second refers to a wrong stack ID.
    req.actions.append(
        take(2, slot(CONTAINER_HOT_BAR, 0, id), slot(CONTAINER_CURSOR, 0, 0))
    )
    req.actions.append(
        take(1, slot(CONTAINER_HOT_BAR, 0, 999), slot(CONTAINER_CURSOR, 0, 0))
    )
    var pk = ItemStackRequestPacket()
    pk.requests.append(req^)
    assert_equal(run(h, pk, invs)[0], ITEM_STACK_RESPONSE_STATUS_ERROR)
    assert_equal(invs.inv.item(0).count(), 10)
    assert_equal(invs.inv.item(0).id(), id)
    assert_true(invs.ui.item(0).empty())


def test_reject_restores_slot_changed_twice() raises:
    # Go restores the state before the slot's last change; Ignis restores
    # the state before the request.
    var invs = Inventories()
    invs.inv.set_item(0, Stack(Stick(), 10))
    var id = invs.inv.item(0).id()
    var h = ItemStackRequestHandler()
    var req = ItemStackRequest()
    req.request_id = -5
    req.actions.append(
        take(2, slot(CONTAINER_HOT_BAR, 0, id), slot(CONTAINER_CURSOR, 0, 0))
    )
    req.actions.append(
        take(1, slot(CONTAINER_HOT_BAR, 0, -5), slot(CONTAINER_CURSOR, 0, -5))
    )
    req.actions.append(
        take(1, slot(CONTAINER_HOT_BAR, 0, 999), slot(CONTAINER_CURSOR, 0, 0))
    )
    var pk = ItemStackRequestPacket()
    pk.requests.append(req^)
    assert_equal(run(h, pk, invs)[0], ITEM_STACK_RESPONSE_STATUS_ERROR)
    assert_equal(invs.inv.item(0).count(), 10)
    assert_true(invs.ui.item(0).empty())


def test_swap_keeps_ids() raises:
    var invs = Inventories()
    invs.inv.set_item(0, Stack(Stick(), 1))
    invs.inv.set_item(1, Stack(Diamond(), 2))
    var a = invs.inv.item(0).id()
    var b = invs.inv.item(1).id()
    var s = SwapStackRequestAction()
    s.source = slot(CONTAINER_HOT_BAR, 0, a)
    s.destination = slot(CONTAINER_HOT_BAR, 1, b)
    var h = ItemStackRequestHandler()
    assert_equal(
        run(h, packet(-1, StackRequestAction(s^)), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_OK,
    )
    assert_equal(invs.inv.item(0).id(), b)
    assert_equal(invs.inv.item(1).id(), a)


def test_destroy_needs_creative() raises:
    var invs = Inventories()
    invs.inv.set_item(3, Stack(Stick(), 5))
    var d = DestroyStackRequestAction()
    d.count = 5
    d.source = slot(CONTAINER_INVENTORY, 3, invs.inv.item(3).id())
    var h = ItemStackRequestHandler()
    var pk = packet(-1, StackRequestAction(d.copy()))
    assert_equal(run(h, pk, invs)[0], ITEM_STACK_RESPONSE_STATUS_ERROR)
    assert_equal(run(h, pk, invs, True)[0], ITEM_STACK_RESPONSE_STATUS_OK)
    assert_true(invs.inv.item(3).empty())


def test_drop_hands_back_the_stack() raises:
    var invs = Inventories()
    invs.inv.set_item(0, Stack(Stick(), 5))
    var d = DropStackRequestAction()
    d.count = 2
    d.source = slot(CONTAINER_HOT_BAR, 0, invs.inv.item(0).id())
    var h = ItemStackRequestHandler()
    var r = run(h, packet(-1, StackRequestAction(d^)), invs)
    assert_equal(r[0], ITEM_STACK_RESPONSE_STATUS_OK)
    assert_equal(len(r[1]), 1)
    assert_equal(r[1][0].count(), 2)
    assert_equal(invs.inv.item(0).count(), 3)


def test_creative_craft_then_take() raises:
    var invs = Inventories()
    var h = ItemStackRequestHandler()
    var req = ItemStackRequest()
    req.request_id = -1
    var c = CraftCreativeStackRequestAction()
    c.creative_item_network_id = 1
    c.number_of_crafts = 1
    req.actions.append(StackRequestAction(c^))
    var created = invs.ui.item(CRAFTING_RESULT).id()
    _ = created
    var pk = ItemStackRequestPacket()
    pk.requests.append(req^)
    assert_equal(run(h, pk, invs)[0], ITEM_STACK_RESPONSE_STATUS_ERROR)
    assert_equal(run(h, pk, invs, True)[0], ITEM_STACK_RESPONSE_STATUS_OK)
    # A full stack of the creative item lands in the created output.
    var out = invs.ui.item(CRAFTING_RESULT)
    assert_equal(out.count(), 64)
    var t = take(
        64,
        slot(CONTAINER_CREATED_OUTPUT, CRAFTING_RESULT, out.id()),
        slot(CONTAINER_HOT_BAR, 4, 0),
    )
    assert_equal(
        run(h, packet(-3, t^), invs, True)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    assert_equal(invs.inv.item(4).count(), 64)


def test_creative_craft_and_take_in_one_request() raises:
    # What the vanilla client sends when it picks a creative item: the take
    # refers to the created output by the request's own ID.
    var invs = Inventories()
    var h = ItemStackRequestHandler()
    var req = ItemStackRequest()
    req.request_id = -7
    var c = CraftCreativeStackRequestAction()
    c.creative_item_network_id = 1
    c.number_of_crafts = 1
    req.actions.append(StackRequestAction(c^))
    req.actions.append(
        take(
            1,
            slot(CONTAINER_CREATED_OUTPUT, CRAFTING_RESULT, -7),
            slot(CONTAINER_HOT_BAR, 0, 0),
        )
    )
    var pk = ItemStackRequestPacket()
    pk.requests.append(req^)
    assert_equal(run(h, pk, invs, True)[0], ITEM_STACK_RESPONSE_STATUS_OK)
    assert_equal(invs.inv.item(0).count(), 1)


def _recipes() raises -> ArcPointer[Recipes]:
    var r = Recipes()
    var reg = ItemRegistry()
    # 1: a log of any kind (tag) gives 4 oak planks.
    var tags = ItemTags.parse(
        String('{"minecraft:logs": ["minecraft:oak_log"]}').as_bytes()
    )
    var logs = RecipeItem(new_item_tag(tags, "minecraft:logs", 1))
    r.register(
        new_shapeless([logs^], Stack(Planks(), 4), "crafting_table"), reg
    )
    # 2: four planks in a square give a crafting table.
    var square = List[RecipeItem]()
    for _ in range(4):
        square.append(RecipeItem(Stack(Planks(), 1)))
    r.register(
        new_shaped(
            square^, Stack(CraftingTable(), 1), Shape(2, 2), "crafting_table"
        ),
        reg,
    )
    # 3: a stonecutter turns one stone into two planks.
    r.register(
        new_shapeless(
            [RecipeItem(Stack(Stone(), 1))], Stack(Planks(), 2), "stonecutter"
        ),
        reg,
    )
    # 4: a smithing table upgrades a diamond into a stick.
    r.register(
        new_smithing_transform(
            RecipeItem(Stack(Diamond(), 1)),
            RecipeItem(Stack(Stick(), 1)),
            RecipeItem(Stack(SmithingTemplate(), 1)),
            Stack(Stick(), 1),
            "smithing_table",
        ),
        reg,
    )
    return ArcPointer(r^)


def craft(id: UInt32, times: Int) -> StackRequestAction:
    var a = CraftRecipeStackRequestAction()
    a.recipe_network_id = id
    a.number_of_crafts = UInt8(times)
    return StackRequestAction(a^)


def test_repeat_stacks() raises:
    var out = repeat_stacks([Stack(Planks(), 4)], 20)
    assert_equal(len(out), 2)
    assert_equal(out[0].count(), 64)
    assert_equal(out[1].count(), 16)


def test_craft_planks_in_the_small_grid() raises:
    var invs = Inventories()
    invs.ui.set_item(28, Stack(Log(), 3))
    var h = ItemStackRequestHandler()
    h.use_recipes(_recipes(), ArcPointer(ItemRegistry()))
    var res = run(h, packet(1, craft(1, 2)), invs)
    assert_equal(res[0], ITEM_STACK_RESPONSE_STATUS_OK)
    assert_equal(invs.ui.item(28).count(), 1)
    var made = invs.ui.item(CRAFTING_RESULT)
    assert_true(made.item_as[Planks]())
    assert_equal(made.count(), 8)


def test_craft_needs_enough_input() raises:
    var invs = Inventories()
    invs.ui.set_item(28, Stack(Log(), 1))
    var h = ItemStackRequestHandler()
    h.use_recipes(_recipes(), ArcPointer(ItemRegistry()))
    var res = run(h, packet(1, craft(1, 2)), invs)
    assert_equal(res[0], ITEM_STACK_RESPONSE_STATUS_ERROR)
    assert_equal(invs.ui.item(28).count(), 1)


def test_crafting_table_uses_the_large_grid() raises:
    var invs = Inventories()
    for s in [32, 33, 35, 36]:
        invs.ui.set_item(s, Stack(Planks(), 1))
    var h = ItemStackRequestHandler()
    h.use_recipes(_recipes(), ArcPointer(ItemRegistry()))
    # Without a crafting table open, the 3x3 slots are not the grid.
    assert_equal(
        run(h, packet(1, craft(2, 1)), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_ERROR,
    )
    invs.window = Window(WINDOW_UI, HASH_CRAFTING_TABLE)
    assert_equal(
        run(h, packet(2, craft(2, 1)), invs)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    assert_true(invs.ui.item(CRAFTING_RESULT).item_as[CraftingTable]())
    assert_true(invs.ui.item(32).empty())


def test_auto_craft_takes_from_the_inventory() raises:
    var invs = Inventories()
    invs.inv.set_item(5, Stack(Planks(), 3))
    invs.inv.set_item(9, Stack(Planks(), 3))
    var h = ItemStackRequestHandler()
    h.use_recipes(_recipes(), ArcPointer(ItemRegistry()))
    var a = AutoCraftRecipeStackRequestAction()
    a.recipe_network_id = 2
    a.number_of_crafts = 1
    var res = run(h, packet(1, StackRequestAction(a^)), invs)
    assert_equal(res[0], ITEM_STACK_RESPONSE_STATUS_OK)
    assert_equal(invs.inv.item(5).count() + invs.inv.item(9).count(), 2)
    assert_true(invs.ui.item(CRAFTING_RESULT).item_as[CraftingTable]())


def test_stonecutting() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_STONECUTTER)
    invs.ui.set_item(3, Stack(Stone(), 2))
    var h = ItemStackRequestHandler()
    h.use_recipes(_recipes(), ArcPointer(ItemRegistry()))
    # A crafting table recipe is no stonecutter recipe.
    assert_equal(
        run(h, packet(1, craft(1, 1)), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_ERROR,
    )
    assert_equal(
        run(h, packet(2, craft(3, 2)), invs)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    assert_true(invs.ui.item(3).empty())
    assert_equal(invs.ui.item(CRAFTING_RESULT).count(), 4)


def test_smithing_transform() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_SMITHING_TABLE)
    # Go's `Comparable` also compares custom names, so the input must be
    # a plain diamond to match the recipe.
    invs.ui.set_item(0x33, Stack(Diamond(), 1))
    invs.ui.set_item(0x34, Stack(Stick(), 1))
    invs.ui.set_item(0x35, Stack(SmithingTemplate(), 1))
    var h = ItemStackRequestHandler()
    h.use_recipes(_recipes(), ArcPointer(ItemRegistry()))
    assert_equal(
        run(h, packet(1, craft(4, 1)), invs)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    var out = invs.ui.item(CRAFTING_RESULT)
    assert_true(out.item_as[Stick]())
    assert_equal(out.count(), 1)
    assert_true(invs.ui.item(0x35).empty())


def grind() -> StackRequestAction:
    return StackRequestAction(CraftGrindstoneRecipeStackRequestAction())


def test_grindstone_strips_all_but_curses() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_GRINDSTONE)
    var s = Stack(Shears(), 1).with_forced_enchantments(
        [Enchantment(EFFICIENCY_ID, 3), Enchantment(CURSE_OF_VANISHING_ID, 1)]
    )
    invs.ui.set_item(0x10, s.with_anvil_cost(5))
    var h = ItemStackRequestHandler()
    assert_equal(
        run(h, packet(1, grind()), invs)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    var out = invs.ui.item(CRAFTING_RESULT)
    assert_equal(len(out.enchantments()), 1)
    assert_equal(Int(out.enchantments()[0].id), CURSE_OF_VANISHING_ID)
    assert_equal(out.anvil_cost(), 0)
    assert_true(invs.ui.item(0x10).empty())
    # Efficiency III costs at least 21 levels; the curse costs nothing.
    assert_equal(len(h.experience_costs), 1)
    assert_equal(h.experience_costs[0], 21)
    assert_equal(grindstone_experience(21, 0), 11)


def test_grindstone_repairs_two_items() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_GRINDSTONE)
    var a = Stack(Shears(), 1)
    var max = a.max_durability()
    invs.ui.set_item(0x10, a.with_durability(100))
    invs.ui.set_item(0x11, a.with_durability(50))
    var h = ItemStackRequestHandler()
    assert_equal(
        run(h, packet(1, grind()), invs)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    var out = invs.ui.item(CRAFTING_RESULT)
    assert_equal(out.durability(), min(150 + max * 5 // 100, max))
    assert_equal(len(h.experience_costs), 0)


def test_grindstone_needs_the_same_type() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_GRINDSTONE)
    invs.ui.set_item(0x10, Stack(Shears(), 1))
    invs.ui.set_item(0x11, Stack(Stick(), 1))
    var h = ItemStackRequestHandler()
    assert_equal(
        run(h, packet(1, grind()), invs)[0], ITEM_STACK_RESPONSE_STATUS_ERROR
    )


def loom(pattern: String) -> StackRequestAction:
    var a = CraftLoomRecipeStackRequestAction()
    a.pattern = pattern
    a.times_crafted = 1
    return StackRequestAction(a^)


def _loom_inputs() raises -> Inventories:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_LOOM)
    invs.ui.set_item(0x09, Stack(Banner(), 1))
    var d = Dye()
    d.colour = Colour(14)
    invs.ui.set_item(0x0A, Stack(d, 2))
    return invs^


def test_loom_adds_a_pattern() raises:
    var invs = _loom_inputs()
    var h = ItemStackRequestHandler()
    assert_equal(
        run(h, packet(1, loom("bo")), invs)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    var out = invs.ui.item(CRAFTING_RESULT)
    assert_true(out.item_as[Banner]())
    var nbt = out.item_nbt()
    var l = nbt.get_list(nbt.root(), "Patterns")
    assert_equal(nbt.length(l), 1)
    assert_equal(nbt.get_string(nbt.at(l, 0), "Pattern"), "bo")
    assert_true(invs.ui.item(0x09).empty())
    assert_equal(invs.ui.item(0x0A).count(), 1)


def test_loom_needs_the_pattern_item() raises:
    var invs = _loom_inputs()
    var h = ItemStackRequestHandler()
    assert_equal(
        run(h, packet(1, loom("cre")), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_ERROR,
    )
    invs.ui.set_item(
        0x0B, Stack(BannerPattern(type=BannerPatternType.CREEPER), 1)
    )
    assert_equal(
        run(h, packet(2, loom("cre")), invs)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    # The pattern item is not used up (Go keeps it).
    assert_equal(invs.ui.item(0x0B).count(), 1)


def anvil_packet(id: Int32, var name: List[String]) -> ItemStackRequestPacket:
    var req = ItemStackRequest()
    req.request_id = id
    var a = CraftRecipeOptionalStackRequestAction()
    a.filter_string_index = 0
    req.actions.append(StackRequestAction(a^))
    req.filter_strings = name^
    var pk = ItemStackRequestPacket()
    pk.requests.append(req^)
    return pk^


def _anvil(level: Int) -> ItemStackRequestHandler:
    var h = ItemStackRequestHandler()
    h.experience_level = level
    return h^


def test_anvil_rename_costs_a_level() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_ANVIL)
    invs.ui.set_item(0x1, Stack(Shears(), 1))
    var h = _anvil(5)
    var st = run(h, anvil_packet(1, ["Snips"]), invs)[0]
    assert_equal(st, ITEM_STACK_RESPONSE_STATUS_OK)
    var out = invs.ui.item(CRAFTING_RESULT)
    assert_equal(out.custom_name(), "Snips")
    assert_equal(h.spent_levels, 1)
    assert_true(h.anvil_used)
    # A rename alone does not double the repair cost (Go).
    assert_equal(out.anvil_cost(), 0)


def test_anvil_needs_experience_outside_creative() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_ANVIL)
    invs.ui.set_item(0x1, Stack(Shears(), 1))
    var h = _anvil(0)
    assert_equal(
        run(h, anvil_packet(1, ["Snips"]), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_ERROR,
    )
    assert_equal(
        run(h, anvil_packet(2, ["Snips"]), invs, True)[0],
        ITEM_STACK_RESPONSE_STATUS_OK,
    )
    assert_equal(h.spent_levels, 0)


def test_anvil_enchants_with_a_book() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_ANVIL)
    invs.ui.set_item(0x1, Stack(Shears(), 1))
    var book = Stack(EnchantedBook(), 1).with_forced_enchantments(
        [Enchantment(UNBREAKING_ID, 2)]
    )
    invs.ui.set_item(0x2, book)
    var h = _anvil(10)
    var st = run(h, anvil_packet(1, List[String]()), invs)[0]
    assert_equal(st, ITEM_STACK_RESPONSE_STATUS_OK)
    var out = invs.ui.item(CRAFTING_RESULT)
    assert_equal(out.enchantment(Int16(UNBREAKING_ID)).value().level, 2)
    # Uncommon (2), halved for a book (1), times level 2.
    assert_equal(h.spent_levels, 2)
    # Shears are not repairable, so Go's WithAnvilCost leaves the cost.
    assert_equal(out.anvil_cost(), 0)
    assert_true(invs.ui.item(0x2).empty())


def test_anvil_joins_two_damaged_items() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_ANVIL)
    var a = Stack(Shears(), 1)
    var max = a.max_durability()
    invs.ui.set_item(0x1, a.with_durability(100))
    invs.ui.set_item(0x2, a.with_durability(50))
    var h = _anvil(10)
    var st = run(h, anvil_packet(1, List[String]()), invs)[0]
    assert_equal(st, ITEM_STACK_RESPONSE_STATUS_OK)
    var out = invs.ui.item(CRAFTING_RESULT)
    assert_equal(out.durability(), min(150 + max * 12 // 100, max))
    assert_equal(h.spent_levels, 2)


def test_enchant_takes_levels_and_lapis() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_ENCHANTING_TABLE)
    invs.ui.set_item(0x0E, Stack(Book(), 1))
    invs.ui.set_item(0x0F, Stack(LapisLazuli(), 5))
    var h = _anvil(30)
    h.enchant_offers = offers_for(Stack(Book(), 1), 42, 15)
    var want = h.enchant_offers.value().enchants[2].copy()
    assert_equal(
        run(h, packet(1, craft(2, 1)), invs)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    var out = invs.ui.item(CRAFTING_RESULT)
    # The third offer costs 3 levels and 3 lapis; a book becomes enchanted.
    assert_true(out.item_as[EnchantedBook]())
    assert_equal(len(out.enchantments()), len(want))
    assert_equal(h.spent_levels, 3)
    assert_equal(invs.ui.item(0x0F).count(), 2)
    assert_true(h.reset_enchant_seed)


def test_enchant_needs_the_offer_level() raises:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_ENCHANTING_TABLE)
    invs.ui.set_item(0x0E, Stack(Book(), 1))
    invs.ui.set_item(0x0F, Stack(LapisLazuli(), 5))
    var h = _anvil(2)
    h.enchant_offers = offers_for(Stack(Book(), 1), 42, 15)
    # The last offer needs 30 levels with 15 shelves (Go: max(base, 2x15)).
    assert_equal(
        run(h, packet(1, craft(2, 1)), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_ERROR,
    )


def _pay(primary: Int32, secondary: Int32) -> StackRequestAction:
    var a = BeaconPaymentStackRequestAction()
    a.primary_effect = primary
    a.secondary_effect = secondary
    return StackRequestAction(a^)


def _beacon(payment: Stack) raises -> Inventories:
    var invs = Inventories()
    invs.window = Window(WINDOW_UI, HASH_BEACON)
    invs.ui.set_item(0x1B, payment)
    return invs^


def test_beacon_payment_sets_effects() raises:
    var invs = _beacon(Stack(Emerald(), 1))
    var h = ItemStackRequestHandler()
    h.beacon_level = 4
    # Regeneration (10) and Speed (1) at level 4.
    assert_equal(
        run(h, packet(1, _pay(1, 10)), invs)[0], ITEM_STACK_RESPONSE_STATUS_OK
    )
    assert_true(invs.ui.item(0x1B).empty())
    var e = h.beacon_effects.value()
    assert_equal(e[0], 1)
    assert_equal(e[1], 10)


def test_beacon_payment_checks_level_and_item() raises:
    var h = ItemStackRequestHandler()
    h.beacon_level = 2
    # Strength (5) needs level 3.
    var invs = _beacon(Stack(Emerald(), 1))
    assert_equal(
        run(h, packet(1, _pay(5, 0)), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_ERROR,
    )
    # A secondary effect needs level 4.
    invs = _beacon(Stack(Emerald(), 1))
    assert_equal(
        run(h, packet(2, _pay(1, 1)), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_ERROR,
    )
    # Sticks are no payment.
    invs = _beacon(Stack(Stick(), 1))
    assert_equal(
        run(h, packet(3, _pay(1, 0)), invs)[0],
        ITEM_STACK_RESPONSE_STATUS_ERROR,
    )
    assert_false(h.beacon_effects)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
