from ignis.block.block import UseContext
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.ender_chest import EnderChest
from ignis.block.obsidian import Obsidian
from ignis.block.register import VanillaBlocks
from ignis.item.tool import ToolInfo
from std.testing import TestSuite, assert_equal, assert_true
from support.world_runtime import RecordingViewer, new_vanilla_world


def test_drops() raises:
    var plain = EnderChest().drops(ToolInfo.none(), False)
    assert_equal(len(plain), 1)
    assert_true(plain[0].item_as[Obsidian]())
    assert_equal(plain[0].count(), 8)
    var silk = EnderChest().drops(ToolInfo.none(), True)
    assert_true(silk[0].item_as[EnderChest]())


def test_activate_and_lid() raises:
    var w = new_vanilla_world()
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    var pos = Pos(1, -60, 1)
    w.set_block(pos, EnderChest())
    var ctx = UseContext()
    assert_true(
        VanillaBlocks.activate(EnderChest.BASE_HASH, pos, Face.UP, w, ctx)
    )
    assert_true(ctx.open_container)
    VanillaBlocks.opened(EnderChest.BASE_HASH, pos, w)
    VanillaBlocks.closed(EnderChest.BASE_HASH, pos, w)
    assert_equal(w.viewer(id).count("block_action (1,-60,1) 0"), 1)
    assert_equal(w.viewer(id).count("block_action (1,-60,1) 1"), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
