from ignis.block.air import Air
from ignis.block.dirt import Dirt
from ignis.block.hash import HASH_DIRT
from ignis.block.stone import Stone
from ignis.world.block import Block
import ignis.world.block_state
from ignis.block.bedrock import Bedrock
from ignis.block.cube.pos import Pos
from ignis.block.register import VanillaBlocks
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from ignis.block.hash import AnyBlock
from ignis.block.short_grass import ShortGrass
from support.block_source import FixedSource
from ignis.block.register import vanilla_block_registry
from support.world_runtime import (
    RandomProbe,
    ScheduledProbe,
    TestBlocks,
    new_world,
)


trait Spreads(Block):
    """A behaviour only some block types have (like Go's RandomTicker)."""

    def spread(self, mut log: List[String]):
        ...


def _spread[T: Spreads](b: T, mut log: List[String]):
    b.spread(log)


@fieldwise_init
struct _Fake(Block, ImplicitlyCopyable, Spreads):
    comptime BASE_HASH: UInt64 = 999
    var level: UInt64

    def encode_block(self) -> ignis.world.block_state.BlockState:
        return ignis.world.block_state.BlockState("fake")

    def hash(self) -> UInt64:
        return self.level

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        return _Fake(hash)

    @staticmethod
    def all_states() -> List[Self]:
        return [_Fake(0)]

    def spread(self, mut log: List[String]):
        log.append(String(t"fake {self.level}"))


struct _Dispatch[*Ts: Block]:
    @staticmethod
    def spread(kind: UInt64, hash: UInt64, mut log: List[String]) -> Bool:
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Spreads):
                if kind == T.BASE_HASH:
                    _spread[T](T.from_hash(hash), log)
                    return True
        return False


def test_dispatch_by_kind() raises:
    var log = List[String]()
    comptime D = _Dispatch[Air, Dirt, _Fake, Stone]
    assert_true(D.spread(999, 7, log))
    # Dirt is in the set but does not conform to Spreads.
    assert_false(D.spread(HASH_DIRT, 0, log))
    assert_equal(len(log), 1)
    assert_equal(log[0], "fake 7")


def test_tick_dispatch() raises:
    var w = new_world(synchronous=True)
    var br = w.block_registry()
    # Only types with the behaviour are dispatched to.
    assert_true(
        TestBlocks.scheduled_tick(ScheduledProbe.BASE_HASH, 0, Pos(0, 0, 0), w)
    )
    assert_true(w.block_as[Dirt](Pos(0, 1, 0)))
    assert_false(TestBlocks.scheduled_tick(HASH_DIRT, 0, Pos(0, 0, 0), w))
    assert_false(
        TestBlocks.neighbour_update_tick(
            ScheduledProbe.BASE_HASH, 0, Pos(0, 0, 0), Pos(1, 0, 0), w
        )
    )
    assert_true(
        TestBlocks.random_tick(RandomProbe.BASE_HASH, 0, Pos(3, 0, 3), w)
    )
    assert_true(w.block_as[Stone](Pos(3, 0, 3)))
    # The registry flags random tickers (Go `RandomTickBlock`).
    assert_true(br[].random_tick_block(br[].block_runtime_id(RandomProbe())))
    assert_false(br[].random_tick_block(br[].block_runtime_id(Dirt())))


def test_interaction_dispatch() raises:
    var stone = Stone()
    var info = VanillaBlocks.break_info(Stone.BASE_HASH, stone.hash()).value()
    assert_equal(info.hardness, 1.5)
    assert_false(Bool(VanillaBlocks.break_info(Air.BASE_HASH, Air().hash())))
    var by = AnyBlock(Dirt.BASE_HASH, Dirt().hash())
    assert_true(VanillaBlocks.replaceable_by(Air.BASE_HASH, Air().hash(), by))
    assert_true(
        VanillaBlocks.replaceable_by(
            ShortGrass.BASE_HASH, ShortGrass().hash(), by
        )
    )
    assert_false(
        VanillaBlocks.replaceable_by(Stone.BASE_HASH, stone.hash(), by)
    )
    var src = FixedSource(vanilla_block_registry("resources/block_states.nbt"))
    assert_equal(
        len(
            VanillaBlocks.model_bbox(
                Air.BASE_HASH, Air().hash(), Pos(0, 0, 0), src
            )
        ),
        0,
    )
    var boxes = VanillaBlocks.model_bbox(
        Stone.BASE_HASH, stone.hash(), Pos(0, 0, 0), src
    )
    assert_equal(len(boxes), 1)
    assert_equal(boxes[0].height(), 1.0)


def test_block_items() raises:
    var it = VanillaBlocks.block_item(Dirt.BASE_HASH, 1).value()
    assert_true(it.item.get[Dirt]().value() == Dirt(coarse=True))
    assert_true(it.item.block)
    var enc = VanillaBlocks.encode_block_item(Bedrock.BASE_HASH, 1).value()
    assert_equal(enc.name, "minecraft:bedrock")
    assert_false(VanillaBlocks.block_item(12345, 0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
