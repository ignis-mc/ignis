from ignis.block.air import Air
from ignis.block.dirt import Dirt
from ignis.block.hash import HASH_DIRT
from ignis.block.stone import Stone
from ignis.world.block import Block
import ignis.world.block_state
from std.testing import TestSuite, assert_equal, assert_false, assert_true


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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
