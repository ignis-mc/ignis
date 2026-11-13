from ignis.block.break_info import AXE_EFFECTIVE, PICKAXE_EFFECTIVE
from ignis.block.cube.direction import Direction
from ignis.block.end_bricks import EndBricks
from ignis.block.hash import AnyBlock
from ignis.block.nether_bricks import NetherBricks
from ignis.block.nether_bricks_type import NetherBricksType
from ignis.block.planks import Planks
from ignis.block.slab import Slab
from ignis.block.stairs import Stairs
from ignis.block.stairs_corner import StairsCorner
from ignis.block.stone_bricks import StoneBricks
from ignis.block.stone_bricks_type import StoneBricksType
from ignis.block.wall import Wall
from ignis.block.wall_connection_type import WallConnectionType
from ignis.block.wood_type import WoodType
from std.testing import TestSuite, assert_equal, assert_true


def test_slab_encoding() raises:
    var s = Slab(block=AnyBlock(Planks(wood=WoodType.SPRUCE)), top=True)
    assert_equal(
        String(s.encode_block()),
        "minecraft:spruce_slab{minecraft:vertical_half=s:top}",
    )
    var d = Slab(block=AnyBlock(Planks()), double=True)
    assert_equal(d.encode_block().name, "minecraft:oak_double_slab")
    assert_equal(d.light_diffusion_level(), 15)
    assert_equal(s.light_diffusion_level(), 0)
    assert_true(Slab.from_hash(s.hash()) == s)


def test_nether_brick_slabs_and_stairs_are_not_swapped() raises:
    # Dragonfly encodes the red nether brick slab as nether_brick_slab and
    # the other way round; Ignis encodes each as its own.
    var red = AnyBlock(NetherBricks(type=NetherBricksType.RED))
    var plain = AnyBlock(NetherBricks())
    assert_equal(
        Slab(block=red).encode_block().name, "minecraft:red_nether_brick_slab"
    )
    assert_equal(
        Slab(block=plain).encode_block().name, "minecraft:nether_brick_slab"
    )
    assert_equal(
        Stairs(block=red).encode_block().name,
        "minecraft:red_nether_brick_stairs",
    )
    assert_equal(
        Stairs(block=plain).encode_block().name,
        "minecraft:nether_brick_stairs",
    )


def test_slab_break_info() raises:
    assert_equal(Slab(block=AnyBlock(EndBricks())).break_info().hardness, 3.0)
    var mossy = AnyBlock(StoneBricks(type=StoneBricksType.MOSSY))
    assert_equal(Slab(block=mossy).break_info().hardness, 1.5)
    assert_equal(Slab(block=AnyBlock(StoneBricks())).break_info().hardness, 2.0)
    var wood = Slab(block=AnyBlock(Planks())).break_info()
    assert_true(wood.effective == AXE_EFFECTIVE)
    assert_equal(wood.blast_resistance, 3.0)


def test_stairs() raises:
    var s = Stairs(
        block=AnyBlock(Planks()),
        upside_down=True,
        facing=Direction.EAST,
        corner=StairsCorner.OUTER_LEFT,
    )
    assert_equal(
        String(s.encode_block()),
        "minecraft:oak_stairs{minecraft:corner=s:outer_left,"
        + "upside_down_bit=b:1,weirdo_direction=i:0}",
    )
    assert_true(Stairs.from_hash(s.hash()) == s)
    assert_true(StairsCorner.OUTER_LEFT.left())
    assert_true(not StairsCorner.OUTER_LEFT.inner())


def test_wall() raises:
    var w = Wall(
        block=AnyBlock(EndBricks()),
        north_connection=WallConnectionType.TALL,
        west_connection=WallConnectionType.SHORT,
        post=True,
    )
    assert_equal(w.encode_block().name, "minecraft:end_stone_brick_wall")
    assert_true(Wall.from_hash(w.hash()) == w)
    assert_true(w.break_info().effective == PICKAXE_EFFECTIVE)
    assert_equal(WallConnectionType.SHORT.height(), 0.75)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
